# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Anonymous topic identity posting" do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }

  before do
    SiteSetting.anonymous_topic_identity_enabled = true
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
  end

  it "writes snapshots on post creation and does not rewrite history" do
    first_post = PostCreator.create!(
      user,
      topic_id: topic.id,
      raw: "first anonymous reply",
      anonymous_enabled: true,
      anonymous_alias: "马甲A"
    )

    second_post = PostCreator.create!(
      user,
      topic_id: topic.id,
      raw: "second anonymous reply",
      anonymous_enabled: true,
      anonymous_alias: "马甲B"
    )

    first_post.reload
    second_post.reload

    expect(first_post.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]).to include("马甲A#")
    expect(second_post.custom_fields[::AnonymousTopicIdentity::Fields::DISPLAY_SNAPSHOT]).to include("马甲B#")

    first_code = first_post.custom_fields[::AnonymousTopicIdentity::Fields::CODE_SNAPSHOT]
    second_code = second_post.custom_fields[::AnonymousTopicIdentity::Fields::CODE_SNAPSHOT]

    expect(first_code).to eq(second_code)
  end
end
