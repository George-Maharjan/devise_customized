class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:profile]

  def profile
    @user = current_user
    @published_blogs = @user.blogs.published.order(created_at: :desc)
    @draft_blogs = @user.blogs.drafts.order(created_at: :desc)
  end
end
