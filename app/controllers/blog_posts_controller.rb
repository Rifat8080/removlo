class BlogPostsController < ApplicationController
  layout "landing"

  def index
    @blog_posts = BlogPost.includes(:author).with_attached_cover_image.published
  end

  def show
    @blog_post = BlogPost.with_attached_cover_image.published.find_by!(slug: params[:id])
    @more_posts = BlogPost.includes(:author).with_attached_cover_image.published.where.not(id: @blog_post.id).limit(3)
  end
end
