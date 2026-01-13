class BlogsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_blog, only: [:show, :edit, :update, :destroy]

  def index
    @blogs = Blog.all.order(created_at: :desc)
  end

  def show
  end

  def new
    @blog = current_user.blogs.build
  end

  def edit
  end

  def create
    @blog = current_user.blogs.build(blog_params)

    if @blog.save
      redirect_to @blog, notice: 'Blog was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @blog.update(blog_params)
      redirect_to @blog, notice: 'Blog was successfully updated.'
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

  def blog_params
    params.require(:blog).permit(:title, :description)
  end
end
