# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def show?
    belongs_to_account?
  end

  def create?
    admin_or_owner?
  end

  def update?
    admin_or_owner?
  end

  def destroy?
    admin_or_owner?
  end

  private

  def account_admin?
    return false unless record

    account_user = AccountUser.find_by(user: user, account: record)
    account_user&.admin?
  end
end
