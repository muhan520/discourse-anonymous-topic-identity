# frozen_string_literal: true

class CreateAnonymousAliasEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :anonymous_alias_events do |t|
      t.bigint :identity_id, null: false
      t.string :old_alias, limit: 100
      t.string :new_alias, null: false, limit: 100
      t.bigint :changed_by_user_id, null: false

      t.timestamps
    end

    add_index :anonymous_alias_events, :identity_id
    add_index :anonymous_alias_events, :changed_by_user_id

    add_foreign_key :anonymous_alias_events,
                    :anonymous_topic_identities,
                    column: :identity_id
    add_foreign_key :anonymous_alias_events,
                    :users,
                    column: :changed_by_user_id
  end
end
