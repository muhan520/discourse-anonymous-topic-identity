# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::AnonymousTopicIdentity::IdentityManager do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }

  before do
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
  end

  it "creates identity once per user/topic" do
    first = described_class.upsert!(user: user, topic_id: topic.id, alias_name: "马甲A")
    second = described_class.upsert!(user: user, topic_id: topic.id, alias_name: "马甲A")

    expect(first.id).to eq(second.id)
    expect(::AnonymousTopicIdentity::Identity.count).to eq(1)
  end

  it "keeps anti_code stable when alias changes" do
    first = described_class.upsert!(user: user, topic_id: topic.id, alias_name: "马甲A")
    second = described_class.upsert!(user: user, topic_id: topic.id, alias_name: "马甲B")

    expect(second.anti_code).to eq(first.anti_code)
    expect(second.current_alias).to eq("马甲B")
    expect(::AnonymousTopicIdentity::AliasEvent.count).to eq(1)
  end
end
