# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::AnonymousTopicIdentity::AntiCodeGenerator do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:other_topic) { Fabricate(:topic) }

  before do
    SiteSetting.anonymous_topic_identity_secret_key = "spec-secret"
    SiteSetting.anonymous_topic_identity_code_length = 7
  end

  it "is stable for the same user and topic" do
    first = described_class.generate(user_id: user.id, topic_id: topic.id)
    second = described_class.generate(user_id: user.id, topic_id: topic.id)

    expect(first).to eq(second)
  end

  it "changes for a different topic" do
    first = described_class.generate(user_id: user.id, topic_id: topic.id)
    second = described_class.generate(user_id: user.id, topic_id: other_topic.id)

    expect(first).not_to eq(second)
  end

  it "respects configured code length" do
    SiteSetting.anonymous_topic_identity_code_length = 9

    code = described_class.generate(user_id: user.id, topic_id: topic.id)

    expect(code.length).to eq(9)
  end
end
