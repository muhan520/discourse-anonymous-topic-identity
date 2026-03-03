# frozen_string_literal: true

class CreateAnonymousTopicIdentities < ActiveRecord::Migration[7.0]
  def change
    create_table :anonymous_topic_identities do |t|
      t.bigint :user_id, null: false
      t.bigint :topic_id, null: false
      t.string :anti_code, null: false, limit: 32
      t.string :current_alias, null: false, limit: 100
      t.integer :code_algo_version, null: false, default: 1

      t.timestamps
    end

    add_index :anonymous_topic_identities, [:user_id, :topic_id], unique: true
    add_index :anonymous_topic_identities, [:topic_id, :anti_code]

    add_foreign_key :anonymous_topic_identities, :users
    add_foreign_key :anonymous_topic_identities, :topics
  end
end
