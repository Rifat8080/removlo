class CreatePlatformChat < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations, id: :uuid do |t|
      t.string :kind, null: false, default: "support"
      t.string :status, null: false, default: "open"
      t.string :subject
      t.string :conversationable_type
      t.uuid :conversationable_id
      t.datetime :last_message_at
      t.timestamps
    end
    add_index :conversations, %i[conversationable_type conversationable_id]
    add_index :conversations, :kind
    add_index :conversations, :status

    create_table :conversation_participants, id: :uuid do |t|
      t.references :conversation, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :participant_role, null: false
      t.datetime :last_read_at
      t.timestamps
    end
    add_index :conversation_participants, %i[conversation_id user_id], unique: true

    create_table :messages, id: :uuid do |t|
      t.references :conversation, null: false, foreign_key: true, type: :uuid
      t.references :sender, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.text :body, null: false
      t.boolean :system_message, default: false, null: false
      t.boolean :internal_only, default: false, null: false
      t.timestamps
    end
    add_index :messages, %i[conversation_id created_at]
  end
end
