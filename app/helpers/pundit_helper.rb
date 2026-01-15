module PunditHelper
  # Wrapper for policy checks that returns boolean
  def policy?(record, query = :view?)
    policy(record).public_send(query)
  rescue Pundit::NotDefinedError
    false
  end

  # Render block only if user is authorized for the action
  def authorized_action?(record, action = :view?)
    policy(record).public_send(action)
  end

  # Helper to check admin access
  def admin?
    current_user&.admin?
  end

  # Helper to check author access
  def author?
    current_user&.author?
  end

  # Helper to check reader access
  def reader?
    current_user&.reader?
  end
end
