class BlogsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_blog, only: [:show, :edit, :update, :destroy]
  before_action :authorize_blog, only: [:edit, :update, :destroy]

  def index
    @blogs = policy_scope(Blog).order(created_at: :desc)
  end

  def show
  end

  def new
    @blog = current_user.blogs.build
    authorize @blog
  end

  def edit
  end

  def create
    @blog = current_user.blogs.build(blog_params)
    authorize @blog

    # Set published based on which button was clicked
    @blog.published = params[:commit] == 'publish'

    if @blog.save
      message = @blog.published? ? 'Blog was successfully published.' : 'Blog was saved as draft.'
      redirect_to @blog, notice: message
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Set published based on which button was clicked
    @blog.published = params[:commit] == 'publish'

    if @blog.update(blog_params)
      message = @blog.published? ? 'Blog was successfully published.' : 'Blog was saved as draft.'
      redirect_to @blog, notice: message
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @blog.destroy
    redirect_to blogs_path, notice: 'Blog was successfully deleted.'
  end

  private

  def set_blog
    @blog = Blog.find(params[:id])
  end

  def authorize_blog
    authorize @blog
  end

  def blog_params
    params.require(:blog).permit(:title, :description, :published)
  end
end
