# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class PostSnapshotWriter
    def self.write!(post:, identity:)
      alias_snapshot = identity.current_alias
      code_snapshot = identity.anti_code

      post.custom_fields[Fields::ALIAS_SNAPSHOT] = alias_snapshot
      post.custom_fields[Fields::CODE_SNAPSHOT] = code_snapshot
      post.custom_fields[Fields::DISPLAY_SNAPSHOT] = "#{alias_snapshot}##{code_snapshot}"
      post.custom_fields[Fields::IDENTITY_ID] = identity.id.to_s
      post.custom_fields[Fields::CODE_ALGO_VERSION] = identity.code_algo_version.to_s

      post.save_custom_fields
    end
  end
end
