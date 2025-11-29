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

  def belongs_to_account?
    user&.account_id == record.id
  end

  def admin_or_owner?
    belongs_to_account? && user&.admin_or_owner?
  end
end
