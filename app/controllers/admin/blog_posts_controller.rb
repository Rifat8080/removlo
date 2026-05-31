module Admin
  class BlogPostsController < BaseController
    before_action :require_admin!
    before_action :set_blog_post, only: %i[show edit update destroy]

    def index
      @blog_posts = BlogPost.includes(:author).with_attached_cover_image.recent
    end

    def show
    end

    def new
      @blog_post = BlogPost.new(published_at: Time.current)
    end

    def edit
    end

    def create
      @blog_post = current_user.blog_posts.new(blog_post_params)

      if @blog_post.save
        redirect_to admin_blog_post_path(@blog_post), notice: "Blog post was published successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @blog_post.update(blog_post_params)
        redirect_to admin_blog_post_path(@blog_post), notice: "Blog post was updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @blog_post.destroy
      redirect_to admin_blog_posts_path, notice: "Blog post was deleted successfully."
    end

    private

    def set_blog_post
      @blog_post = BlogPost.find_by!(slug: params[:id])
    end

    def blog_post_params
      params.require(:blog_post).permit(:title, :slug, :excerpt, :body, :cover_image, :published_at)
    end

    def require_admin!
      return if current_user&.admin?

      redirect_to dashboard_path, alert: "You are not authorized to manage blog posts."
    end
  end
end
