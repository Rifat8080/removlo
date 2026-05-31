class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :actor, foreign_key: { to_table: :users }, type: :uuid
      t.string :event_type, null: false
      t.string :title, null: false
      t.text :body
      t.string :url
      t.string :notifiable_type
      t.uuid :notifiable_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:notifiable_type, :notifiable_id]
    add_index :notifications, [:user_id, :read_at]
    add_index :notifications, [:user_id, :created_at]

    create_table :web_push_subscriptions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :endpoint, null: false
      t.text :p256dh_key, null: false
      t.text :auth_key, null: false
      t.string :user_agent
      t.datetime :last_success_at
      t.datetime :last_failure_at
      t.text :last_error

      t.timestamps
    end

    add_index :web_push_subscriptions, :endpoint, unique: true
  end
end
