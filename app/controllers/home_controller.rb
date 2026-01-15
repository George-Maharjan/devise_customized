class HomeController < ApplicationController
  def index
    if user_signed_in?
      @user_blogs = current_user.blogs.published.order(created_at: :desc).limit(5)
    end
    @recent_blogs = Blog.published.order(created_at: :desc).limit(10)
  end
end
