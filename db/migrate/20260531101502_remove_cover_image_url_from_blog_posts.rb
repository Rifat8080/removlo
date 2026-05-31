class RemoveCoverImageUrlFromBlogPosts < ActiveRecord::Migration[8.0]
  def change
    remove_column :blog_posts, :cover_image_url, :string
  end
end
