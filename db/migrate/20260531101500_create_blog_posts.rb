class CreateBlogPosts < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_posts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :author, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt
      t.text :body, null: false
      t.string :cover_image_url
      t.datetime :published_at, null: false

      t.timestamps
    end

    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :published_at
  end
end
