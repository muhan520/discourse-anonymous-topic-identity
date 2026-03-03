# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class AnonymizedUserMapper
    EMPTY_MARKER = :__anonymous_topic_identity_empty__
    CACHE_KEY = :anonymous_topic_identity_snapshot_cache

    def self.snapshot_for(topic_id:, user_id:)
      topic_id = topic_id.to_i
      user_id = user_id.to_i
      return nil if topic_id <= 0 || user_id <= 0

      key = [topic_id, user_id]
      cached = cache[key]
      return nil if cached == EMPTY_MARKER
      return cached if cached.present?

      snapshot =
        PostCustomField
          .joins(:post)
          .where(name: Fields::DISPLAY_SNAPSHOT, posts: { topic_id: topic_id, user_id: user_id })
          .order("posts.post_number DESC")
          .limit(1)
          .pick(:value)
          .to_s
          .strip

      cache[key] = snapshot.present? ? snapshot : EMPTY_MARKER

      snapshot.presence
    end

    def self.anonymous_in_topic?(topic_id:, user_id:)
      snapshot_for(topic_id: topic_id, user_id: user_id).present?
    end

    def self.pseudo_user_id(topic_id:, user_id:)
      topic_id = topic_id.to_i
      user_id = user_id.to_i
      -((topic_id * 1_000_000_000) + user_id)
    end

    def self.pseudo_user(topic_id:, user_id:)
      snapshot = snapshot_for(topic_id: topic_id, user_id: user_id)
      return nil if snapshot.blank?

      {
        id: pseudo_user_id(topic_id: topic_id, user_id: user_id),
        username: "anonymous",
        name: snapshot,
        avatar_template: User.avatar_template("anonymous", nil),
      }
    end

    def self.cache
      if defined?(RequestStore) && RequestStore.respond_to?(:store)
        RequestStore.store[CACHE_KEY] ||= {}
      else
        Thread.current[CACHE_KEY] ||= {}
      end
    end

    private_class_method :cache
  end
end
