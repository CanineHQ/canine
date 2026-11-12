# frozen_string_literal: true

class AccountUserPolicy < ApplicationPolicy
  def update?
    return false if record.owner? || record == user

    user.admin_or_owner?
  end

  def destroy?
    return false if record.owner? || record == user

    user.admin_or_owner?
  end
end
