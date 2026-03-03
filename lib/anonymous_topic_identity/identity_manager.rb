# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class IdentityManager
    def self.upsert!(user:, topic_id:, alias_name:)
      identity = fetch_or_create!(user_id: user.id, topic_id: topic_id, alias_name: alias_name)

      return identity if identity.current_alias == alias_name

      Identity.transaction do
        identity.lock!
        identity.reload

        next if identity.current_alias == alias_name

        old_alias = identity.current_alias

        identity.update!(current_alias: alias_name)

        AliasEvent.create!(
          identity_id: identity.id,
          old_alias: old_alias,
          new_alias: alias_name,
          changed_by_user_id: user.id
        )
      end

      identity.reload
    end

    def self.fetch_or_create!(user_id:, topic_id:, alias_name:)
      loop do
        identity = Identity.find_by(user_id: user_id, topic_id: topic_id)
        return identity if identity.present?

        begin
          return Identity.create!(
            user_id: user_id,
            topic_id: topic_id,
            anti_code: AntiCodeGenerator.generate(user_id: user_id, topic_id: topic_id),
            current_alias: alias_name,
            code_algo_version: Code::ALGORITHM_VERSION
          )
        rescue ActiveRecord::RecordNotUnique
          # Retry find path when concurrent insert wins.
        end
      end
    end

    private_class_method :fetch_or_create!
  end
end
