# frozen_string_literal: true

module ::AnonymousTopicIdentity
  PLUGIN_NAME = "discourse-anonymous-topic-identity"

  module Fields
    ALIAS_SNAPSHOT = "anon_alias_snapshot"
    CODE_SNAPSHOT = "anon_code_snapshot"
    DISPLAY_SNAPSHOT = "anon_display_name_snapshot"
    IDENTITY_ID = "anon_identity_id"
    CODE_ALGO_VERSION = "anon_code_algo_version"
  end

  module Code
    ALGORITHM_VERSION = 1
  end

  def self.enabled?
    SiteSetting.anonymous_topic_identity_enabled
  end
end
