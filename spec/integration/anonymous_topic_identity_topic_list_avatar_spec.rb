# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Anonymous topic identity topic list avatars" do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  fab!(:staff) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic, user: user) }

  before do
    SiteSetting.anonymous_topic_identity_enabled = true
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
  end

  it "shows only the topic owner in avatar stack for both non-staff and staff" do
    PostCreator.create!(
      user,
      topic_id: topic.id,
      raw: "anonymous reply",
      anonymous_enabled: true,
      anonymous_alias: "马甲A"
    )
    PostCreator.create!(
      other_user,
      topic_id: topic.id,
      raw: "normal reply"
    )

    pseudo_user_id =
      ::AnonymousTopicIdentity::AnonymizedUserMapper.pseudo_user_id(topic_id: topic.id, user_id: user.id)

    non_staff_payload = TopicListItemSerializer.new(topic, scope: Guardian.new(viewer), root: false).as_json
    non_staff_poster_user_ids = Array(non_staff_payload[:posters]).map { |poster| poster[:user_id] }

    staff_payload = TopicListItemSerializer.new(topic, scope: Guardian.new(staff), root: false).as_json
    staff_poster_user_ids = Array(staff_payload[:posters]).map { |poster| poster[:user_id] }

    expect(non_staff_poster_user_ids).to eq([pseudo_user_id])
    expect(non_staff_poster_user_ids).not_to include(other_user.id)

    expect(staff_poster_user_ids).to eq([user.id])
    expect(staff_poster_user_ids).not_to include(other_user.id)
  end
end
