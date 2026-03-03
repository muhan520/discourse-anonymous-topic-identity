# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::AnonymousTopicIdentity::AliasValidator do
  before do
    SiteSetting.anonymous_topic_identity_alias_min_length = 2
    SiteSetting.anonymous_topic_identity_alias_max_length = 20
    SiteSetting.anonymous_topic_identity_extra_denylist = "badword,admin"
  end

  it "accepts a valid alias" do
    validator = described_class.new("树洞_001")

    expect(validator.valid?).to eq(true)
  end

  it "rejects blank alias" do
    validator = described_class.new("  ")

    expect(validator.valid?).to eq(false)
  end

  it "rejects blocked alias" do
    validator = described_class.new("admin")

    expect(validator.valid?).to eq(false)
  end

  it "rejects unsupported characters" do
    validator = described_class.new("hello!")

    expect(validator.valid?).to eq(false)
  end
end
