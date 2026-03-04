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

  add_to_class(:basic_user_serializer, :avatar_template) do
    if Hash === object && object[:avatar_template].present?
      object[:avatar_template]
    else
      super()
    end
  end

  extract_item_user_id =
    lambda do |item|
      return if item.blank?

      if item.respond_to?(:user_id)
        user_id = item.user_id
        return user_id if user_id.present?
      end

      if Hash === item
        user_id = item[:user_id] || item["user_id"] || item[:id] || item["id"]
        return user_id if user_id.present?

        nested_user = item[:user] || item["user"]
        if Hash === nested_user
          user_id = nested_user[:id] || nested_user["id"]
          return user_id if user_id.present?
        elsif nested_user.respond_to?(:id)
          user_id = nested_user.id
          return user_id if user_id.present?
        end
      end

      if item.respond_to?(:user) && item.user.respond_to?(:id)
        user_id = item.user.id
        return user_id if user_id.present?
      end

      if item.respond_to?(:id)
        user_id = item.id
        return user_id if user_id.present?
      end

      nil
    end

  topic_owner_user =
    lambda do |topic|
      return nil if topic.blank? || topic.user_id.blank?

      owner = topic.respond_to?(:user) ? topic.user : nil
      owner ||= User.find_by(id: topic.user_id) if owner.blank?
      owner
    end

  topic_owner_display_user =
    lambda do |topic, owner_user|
      return owner_user if topic.blank? || topic.id.blank? || topic.user_id.blank?

      pseudo_user =
        ::AnonymousTopicIdentity::AnonymizedUserMapper.pseudo_user(topic_id: topic.id, user_id: topic.user_id)

      pseudo_user.presence || owner_user
    end

  build_topic_owner_poster =
    lambda do |topic, source_item, owner_user|
      return nil if topic.blank? || topic.user_id.blank?

      display_user = topic_owner_display_user.call(topic, owner_user)
      return nil if display_user.blank?

      poster = TopicPoster.new
      poster.user = display_user

      if source_item.respond_to?(:description)
        poster.description = source_item.description
      elsif Hash === source_item
        poster.description = source_item[:description] || source_item["description"]
      end

      if source_item.respond_to?(:extras)
        poster.extras = source_item.extras
      elsif Hash === source_item
        poster.extras = source_item[:extras] || source_item["extras"]
      end

      if source_item.respond_to?(:primary_group)
        poster.primary_group = source_item.primary_group
      elsif Hash === source_item
        poster.primary_group = source_item[:primary_group] || source_item["primary_group"]
      end

      if source_item.respond_to?(:flair_group)
        poster.flair_group = source_item.flair_group
      elsif Hash === source_item
        poster.flair_group = source_item[:flair_group] || source_item["flair_group"]
      end

      poster
    end

  add_to_class(:topic_poster_serializer, :user_id) do
    topic_id = object.respond_to?(:topic_id) ? object.topic_id : nil
    topic_id ||= object.respond_to?(:topic) ? object.topic&.id : nil

    source_user_id = extract_item_user_id.call(object)
    source_user_id ||= extract_item_user_id.call(object.user) if object.respond_to?(:user)

    return super() if topic_id.blank? || source_user_id.blank?
    return super() unless ::AnonymousTopicIdentity::AnonymizedUserMapper.anonymous_in_topic?(
      topic_id: topic_id,
      user_id: source_user_id
    )

    ::AnonymousTopicIdentity::AnonymizedUserMapper.pseudo_user_id(topic_id: topic_id, user_id: source_user_id)
  end

  add_to_class(:topic_list_item_serializer, :posters) do
    posters = Array(super())
    topic = object

    op_user_id = topic&.user_id
    return posters if op_user_id.blank?

    owner_user = topic_owner_user.call(topic)
    source_poster = posters.find { |poster| extract_item_user_id.call(poster).to_i == op_user_id.to_i }
    source_poster ||= posters.first

    owner_poster = build_topic_owner_poster.call(topic, source_poster, owner_user)
    owner_poster.present? ? [owner_poster] : posters.first(1)
  end

  add_to_class(:topic_list_item_serializer, :participants) do
    participants = Array(super())
    topic = object

    op_user_id = topic&.user_id
    return participants if op_user_id.blank?

    owner_user = topic_owner_user.call(topic)
    source_participant =
      participants.find { |participant| extract_item_user_id.call(participant).to_i == op_user_id.to_i }
    source_participant ||= participants.first

    owner_participant = build_topic_owner_poster.call(topic, source_participant, owner_user)
    owner_participant.present? ? [owner_participant] : participants.first(1)
  end

  add_to_class(:topic_list_serializer, :users) do
    users = []
    topics = object&.topics || []

    topics.each do |topic|
      next if topic.blank? || topic.user_id.blank?

      owner_user = topic_owner_user.call(topic)
      display_user = topic_owner_display_user.call(topic, owner_user)
      users << display_user if display_user.present?
    end

    users.uniq do |user|
      Hash === user ? user[:id] : user.id
    end
  end

  add_to_class(:category_and_topic_lists_serializer, :users) do
    users = []
    topics = object&.topic_list&.topics || []

    topics.each do |topic|
      next if topic.blank? || topic.user_id.blank?

      owner_user = topic_owner_user.call(topic)
      display_user = topic_owner_display_user.call(topic, owner_user)
      users << display_user if display_user.present?
    end

    users.uniq do |user|
      Hash === user ? user[:id] : user.id
    end
  end

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
