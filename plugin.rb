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
  require_relative "lib/anonymous_topic_identity/anonymized_user_mapper"

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

    add_to_class(serializer_class, :name) do
      snapshot = object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]
      return object.user&.name if snapshot.blank? || scope&.is_staff?

      snapshot
    end

    add_to_class(serializer_class, :username) do
      snapshot = object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]
      return object.user&.username || object.username if snapshot.blank? || scope&.is_staff?

      snapshot
    end

    add_to_class(serializer_class, :display_username) do
      snapshot = object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]
      return object.user&.username || object.username if snapshot.blank? || scope&.is_staff?

      snapshot
    end

    add_to_class(serializer_class, :avatar_template) do
      snapshot = object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]
      return object.user&.avatar_template if snapshot.blank? || scope&.is_staff?

      User.avatar_template("anonymous", nil)
    end

    add_to_class(serializer_class, :include_anonymous_real_user_id?) do
      scope&.is_staff? && object.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT].present?
    end

    add_to_serializer(serializer_name, :anonymous_real_user_id, true) { object.user_id }
  end

  if defined?(::BasicUserSerializer)
    add_to_class(:basic_user_serializer, :avatar_template) do
      if Hash === object && object[:avatar_template].present?
        object[:avatar_template]
      else
        super()
      end
    end
  end

  if defined?(::TopicPosterSerializer)
    add_to_class(:topic_poster_serializer, :user_id) do
      return super() if scope&.is_staff?

      topic_id = object.respond_to?(:topic_id) ? object.topic_id : nil
      source_user_id = object.respond_to?(:user_id) ? object.user_id : nil

      return super() if topic_id.blank? || source_user_id.blank?
      return super() unless ::AnonymousTopicIdentity::AnonymizedUserMapper.anonymous_in_topic?(
        topic_id: topic_id,
        user_id: source_user_id
      )

      ::AnonymousTopicIdentity::AnonymizedUserMapper.pseudo_user_id(topic_id: topic_id, user_id: source_user_id)
    end
  end

  if defined?(::TopicListItemSerializer)
    add_to_class(:topic_list_item_serializer, :posters) do
      posters = super()
      return posters if posters.blank?

      op_user_id = object&.user_id
      return posters if op_user_id.blank?

      only_op =
        posters.select do |poster|
          poster_user_id =
            if poster.respond_to?(:user_id)
              poster.user_id
            elsif Hash === poster
              poster[:user_id] || poster["user_id"]
            end

          poster_user_id.to_i == op_user_id.to_i
        end

      only_op.presence || posters.first(1)
    end
  end

  if defined?(::CategoryAndTopicListsSerializer)
    add_to_class(:category_and_topic_lists_serializer, :users) do
      users = []
      topics = object&.topic_list&.topics || []

      topics.each do |topic|
        op_user = topic.respond_to?(:user) ? topic.user : nil
        next if op_user.blank?

        if !scope&.is_staff? && ::AnonymousTopicIdentity::AnonymizedUserMapper.anonymous_in_topic?(
          topic_id: topic.id,
          user_id: op_user.id
        )
          users << ::AnonymousTopicIdentity::AnonymizedUserMapper.pseudo_user(topic_id: topic.id, user_id: op_user.id)
        else
          users << op_user
        end
      end

      users.uniq do |user|
        Hash === user ? user[:id] : user.id
      end
    end
  end

  if defined?(::TopicViewDetailsSerializer)
    add_to_class(:topic_view_details_serializer, :participants) do
      topic =
        if object.respond_to?(:topic)
          object.topic
        elsif object.respond_to?(:topic_id)
          Topic.find_by(id: object.topic_id)
        end

      return super() if topic.blank? || topic.user_id.blank?

      op_user_id = topic.user_id

      if !scope&.is_staff?
        pseudo_user = ::AnonymousTopicIdentity::AnonymizedUserMapper.pseudo_user(
          topic_id: topic.id,
          user_id: op_user_id
        )
        return [pseudo_user] if pseudo_user.present?
      end

      op_user = topic.respond_to?(:user) ? topic.user : User.find_by(id: op_user_id)
      op_user.present? ? [op_user] : []
    end
  end
end
