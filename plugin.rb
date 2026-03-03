# frozen_string_literal: true

# name: discourse-anonymous-topic-identity
# about: Content-level anonymous posting with per-topic anti-sockpuppet codes.
# version: 0.1.0
# authors: Codex
# url: https://github.com/discourse/discourse-anonymous-topic-identity

enabled_site_setting :anonymous_topic_identity_enabled

register_asset "stylesheets/common/anonymous-topic-identity.scss"

require_relative "lib/anonymous_topic_identity"

after_initialize do
  add_permitted_post_create_param :anonymous_enabled
  add_permitted_post_create_param :anonymous_alias

  require_relative "app/models/anonymous_topic_identity/identity"
  require_relative "app/models/anonymous_topic_identity/alias_event"

  require_relative "lib/anonymous_topic_identity/params"
  require_relative "lib/anonymous_topic_identity/alias_validator"
  require_relative "lib/anonymous_topic_identity/preflight_validator"
  require_relative "lib/anonymous_topic_identity/anti_code_generator"
  require_relative "lib/anonymous_topic_identity/identity_manager"
  require_relative "lib/anonymous_topic_identity/post_snapshot_writer"
  require_relative "lib/anonymous_topic_identity/post_created_handler"
  require_relative "lib/anonymous_topic_identity/post_creator_extension"

  ::PostCreator.prepend(::AnonymousTopicIdentity::PostCreatorExtension)

  DiscourseEvent.on(:post_created) do |post, opts, user|
    next unless ::AnonymousTopicIdentity.enabled?
    next unless ::AnonymousTopicIdentity::Params.anonymous_enabled?(opts)

    ::AnonymousTopicIdentity::PostCreatedHandler.run(post: post, opts: opts, user: user)
  rescue StandardError => e
    Rails.logger.warn(
      "[#{::AnonymousTopicIdentity::PLUGIN_NAME}] post_created handling failed for post_id=#{post&.id}: #{e.class}: #{e.message}"
    )
  end

  [:basic_post, :post].each do |serializer_name|
    add_to_serializer(serializer_name, :anonymous, false) do
      object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT].present?
    end

    add_to_serializer(serializer_name, :anonymous_display_name, false) do
      object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]
    end

    serializer_class = "#{serializer_name}_serializer".to_sym

    add_to_class(serializer_class, :include_anonymous_real_user_id?) do
      scope&.is_staff? && object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT].present?
    end

    add_to_serializer(serializer_name, :anonymous_real_user_id, true) { object.user_id }
  end
end
