# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class PreflightValidator
    def self.validate!(user:, opts:, errors:)
      return true unless ::AnonymousTopicIdentity.enabled?
      return true unless Params.anonymous_enabled?(opts)

      unless user&.id
        errors.add(:base, I18n.t("anonymous_topic_identity.errors.login_required"))
        return false
      end

      validator = AliasValidator.new(Params.anonymous_alias(opts))
      return true if validator.valid?

      errors.add(:base, validator.error_message)
      false
    end
  end
end
