# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class AliasEvent < ActiveRecord::Base
    self.table_name = "anonymous_alias_events"

    belongs_to :identity,
               class_name: "::AnonymousTopicIdentity::Identity",
               foreign_key: :identity_id,
               inverse_of: :alias_events

    belongs_to :changed_by_user,
               class_name: "User",
               foreign_key: :changed_by_user_id

    validates :identity_id, :new_alias, :changed_by_user_id, presence: true
  end
end
