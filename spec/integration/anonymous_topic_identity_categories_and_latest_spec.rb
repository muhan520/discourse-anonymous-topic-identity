# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Anonymous topic identity categories and latest avatars" do
  fab!(:anonymous_owner) { Fabricate(:user) }
  fab!(:normal_owner) { Fabricate(:user) }
  fab!(:replier) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  fab!(:staff) { Fabricate(:admin) }
  fab!(:anonymous_topic) { Fabricate(:topic, user: anonymous_owner) }
  fab!(:normal_topic) { Fabricate(:topic, user: normal_owner) }

  before do
    SiteSetting.anonymous_topic_identity_enabled = true
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
  end

  def serialize_categories_and_latest(scope_user)
    topic_list = TopicList.new("latest", scope_user, [anonymous_topic, normal_topic])
    topic_list.per_page = 30

    result = CategoryAndTopicLists.new
    result.topic_list = topic_list

    CategoryAndTopicListsSerializer.new(result, scope: Guardian.new(scope_user), root: false).as_json
  end

  def posters_for(payload, topic_id)
    topics = Array(payload.dig(:topic_list, :topics))
    topic_payload = topics.find { |topic| topic[:id] == topic_id }
    Array(topic_payload&.dig(:posters))
  end

  it "shows only topic owners and maps anonymous owner to anonymous avatar for viewer and staff" do
    PostCreator.create!(
      anonymous_owner,
      topic_id: anonymous_topic.id,
      raw: "anonymous reply",
      anonymous_enabled: true,
      anonymous_alias: "马甲A"
    )
    PostCreator.create!(replier, topic_id: anonymous_topic.id, raw: "reply after anonymous")
    PostCreator.create!(replier, topic_id: normal_topic.id, raw: "reply to normal topic")

    pseudo_user_id =
      ::AnonymousTopicIdentity::AnonymizedUserMapper.pseudo_user_id(
        topic_id: anonymous_topic.id,
        user_id: anonymous_owner.id
      )

    [viewer, staff].each do |scope_user|
      payload = serialize_categories_and_latest(scope_user)

      anonymous_posters = posters_for(payload, anonymous_topic.id)
      normal_posters = posters_for(payload, normal_topic.id)

      expect(anonymous_posters.size).to eq(1)
      expect(normal_posters.size).to eq(1)
      expect(anonymous_posters.map { |poster| poster[:user_id] }).to eq([pseudo_user_id])
      expect(normal_posters.map { |poster| poster[:user_id] }).to eq([normal_owner.id])
      expect(anonymous_posters.map { |poster| poster[:user_id] }).not_to include(replier.id)
      expect(normal_posters.map { |poster| poster[:user_id] }).not_to include(replier.id)

      user_payloads = Array(payload[:users])
      user_ids = user_payloads.map { |user| user[:id] }

      expect(user_ids).to include(pseudo_user_id)
      expect(user_ids).to include(normal_owner.id)
      expect(user_ids).not_to include(anonymous_owner.id)
      expect(user_ids).not_to include(replier.id)

      anonymous_user_payload = user_payloads.find { |user| user[:id] == pseudo_user_id }
      expect(anonymous_user_payload[:avatar_template]).to eq(User.avatar_template("anonymous", nil))
    end
  end
end
