class BlogPolicy < ApplicationPolicy
  # Helper method to check blog ownership
  def own_blog?
    record.user == user
  end

  # Everyone can view blogs (index and show)
  def index?
    true
  end

  def show?
    true
  end

  # Only authors and admins can create blogs
  def new?
    user.present? && (user.author? || user.admin?)
  end

  def create?
    new?
  end

  # Only the blog owner or admin can edit/delete
  def edit?
    user.present? && (own_blog? || user.admin?)
  end

  def update?
    edit?
  end

  def destroy?
    edit?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
