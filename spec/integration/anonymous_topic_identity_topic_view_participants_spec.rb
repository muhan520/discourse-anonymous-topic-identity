# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Anonymous topic identity topic view participants" do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  fab!(:staff) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic, user: user) }

  before do
    SiteSetting.anonymous_topic_identity_enabled = true
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
  end

  def details_payload_for(target_user)
    topic_view = TopicView.new(topic.id, target_user)
    TopicViewDetailsSerializer.new(topic_view.details, scope: Guardian.new(target_user), root: false).as_json
  end

  it "shows only the topic owner in participants for both non-staff and staff" do
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

    non_staff_participants = Array(details_payload_for(viewer)[:participants])
    staff_participants = Array(details_payload_for(staff)[:participants])

    non_staff_ids = non_staff_participants.map { |participant| participant[:id] }
    staff_ids = staff_participants.map { |participant| participant[:id] }

    expect(non_staff_ids).to eq([pseudo_user_id])
    expect(non_staff_ids).not_to include(other_user.id)

    expect(staff_ids).to eq([user.id])
    expect(staff_ids).not_to include(other_user.id)

    non_staff_pseudo =
      non_staff_participants.find { |participant| participant[:id] == pseudo_user_id }
    expect(non_staff_pseudo[:avatar_template]).to eq(User.avatar_template("anonymous", nil))
  end
end
