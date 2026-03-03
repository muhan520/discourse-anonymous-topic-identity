# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class PostCreatedHandler
    def self.run(post:, opts:, user:)
      return if post.blank? || user.blank? || post.topic_id.blank?

      alias_name = Params.anonymous_alias(opts)
      identity = IdentityManager.upsert!(user: user, topic_id: post.topic_id, alias_name: alias_name)

      PostSnapshotWriter.write!(post: post, identity: identity)
    end
  end
end
