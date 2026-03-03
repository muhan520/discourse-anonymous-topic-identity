# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Anonymous topic identity serializer" do
  fab!(:user) { Fabricate(:user) }
  fab!(:viewer) { Fabricate(:user) }
  fab!(:staff) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic) }

  before do
    SiteSetting.anonymous_topic_identity_enabled = true
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
  end

  def serialize(post, scope_user)
    PostSerializer.new(post, scope: Guardian.new(scope_user), root: false).as_json
  end

  it "renders alias plus anti-code to non-staff viewers" do
    post = PostCreator.create!(
      user,
      topic_id: topic.id,
      raw: "anonymous post",
      anonymous_enabled: true,
      anonymous_alias: "伤心的小马"
    )
    post.reload

    payload = serialize(post, viewer)
    snapshot = post.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]

    expect(snapshot).to include("伤心的小马#")
    expect(payload[:anonymous]).to eq(true)
    expect(payload[:anonymous_display_name]).to eq(snapshot)
    expect(payload[:name]).to eq(snapshot)
    expect(payload[:username]).to eq(snapshot)
    expect(payload[:display_username]).to eq(snapshot)
  end

  it "keeps real account fields for staff viewers" do
    post = PostCreator.create!(
      user,
      topic_id: topic.id,
      raw: "staff view",
      anonymous_enabled: true,
      anonymous_alias: "伤心的小马"
    )
    post.reload

    payload = serialize(post, staff)

    expect(payload[:anonymous]).to eq(true)
    expect(payload[:username]).to eq(user.username)
    expect(payload[:display_username]).to eq(user.username)
  end
end
