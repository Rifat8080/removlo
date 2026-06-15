module Admin
  class BlogPostsController < BaseController
    before_action :require_admin!
    before_action :set_blog_post, only: %i[show edit update destroy]

    def index
      authorize! :read, BlogPost
      @blog_posts = BlogPost.includes(:author).with_attached_cover_image.recent
    end

    def show
      authorize! :read, @blog_post
    end

    def new
      @blog_post = BlogPost.new(published_at: Time.current)
      authorize! :create, @blog_post
    end

    def edit
      authorize! :update, @blog_post
    end

    def create
      @blog_post = current_user.blog_posts.new(blog_post_params)
      authorize! :create, @blog_post

      if @blog_post.save
        redirect_to admin_blog_post_path(@blog_post), notice: "Blog post was published successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      authorize! :update, @blog_post

      if @blog_post.update(blog_post_params)
        redirect_to admin_blog_post_path(@blog_post), notice: "Blog post was updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, @blog_post

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
      authorize! :manage, :all
    rescue CanCan::AccessDenied
      redirect_to dashboard_path, alert: "You are not authorized to manage blog posts."
    end
  end
end
