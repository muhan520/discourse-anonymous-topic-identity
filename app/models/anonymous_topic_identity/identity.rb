# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class Identity < ActiveRecord::Base
    self.table_name = "anonymous_topic_identities"

    belongs_to :user
    belongs_to :topic

    has_many :alias_events,
             class_name: "::AnonymousTopicIdentity::AliasEvent",
             foreign_key: :identity_id,
             inverse_of: :identity,
             dependent: :destroy

    validates :user_id, :topic_id, :anti_code, :current_alias, :code_algo_version, presence: true
  end
end
