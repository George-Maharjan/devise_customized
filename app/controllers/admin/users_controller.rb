class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :deactivate, :activate]
  before_action :authorize_admin

  def index
    @users = policy_scope(User).order(created_at: :desc)
  end

  def show
    authorize @user
  end

  def edit
    authorize @user
  end

  def update
    authorize @user

    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'User was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    authorize @user, :deactivate?

    @user.deactivate!
    redirect_to admin_users_path, notice: "User #{@user.username} has been deactivated."
  end

  def activate
    authorize @user, :activate?

    @user.activate!
    redirect_to admin_users_path, notice: "User #{@user.username} has been activated."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_admin
    authorize User, :index?
  end

  def user_params
    params.require(:user).permit(:email, :username, :role)
  end
end
