# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::AnonymousTopicIdentity::AnonymizedUserMapper do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: user) }

  before do
    SiteSetting.anonymous_topic_identity_enabled = true
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
  end

  it "builds pseudo user for an anonymous identity in the topic" do
    post =
      PostCreator.create!(
        user,
        topic_id: topic.id,
        raw: "anonymous reply",
        anonymous_enabled: true,
        anonymous_alias: "伤心的小马"
      )
    post.reload

    snapshot = described_class.snapshot_for(topic_id: topic.id, user_id: user.id)
    pseudo_user = described_class.pseudo_user(topic_id: topic.id, user_id: user.id)

    expect(snapshot).to include("伤心的小马#")
    expect(described_class.anonymous_in_topic?(topic_id: topic.id, user_id: user.id)).to eq(true)
    expect(pseudo_user[:id]).to eq(described_class.pseudo_user_id(topic_id: topic.id, user_id: user.id))
    expect(pseudo_user[:username]).to eq("anonymous")
    expect(pseudo_user[:name]).to eq(snapshot)
    expect(pseudo_user[:avatar_template]).to eq(User.avatar_template("anonymous", nil))
  end

  it "returns nil pseudo user when there is no anonymous snapshot" do
    expect(described_class.snapshot_for(topic_id: topic.id, user_id: user.id)).to be_nil
    expect(described_class.anonymous_in_topic?(topic_id: topic.id, user_id: user.id)).to eq(false)
    expect(described_class.pseudo_user(topic_id: topic.id, user_id: user.id)).to be_nil
  end
end
