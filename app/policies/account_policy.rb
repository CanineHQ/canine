# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def admin?
    account_admin?
  end

  def manage_stack_manager?
    account_admin?
  end

  private

  def account_admin?
    return false unless record

    account_user = AccountUser.find_by(user: user, account: record)
    account_user&.admin?
  end
end
