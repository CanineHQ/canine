# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def new?
    create?
  end

  def edit?
    update?
  end

  def show?
    user.present?
  end

  def create?
    user&.admin_or_owner?
  end

  def update?
    user&.admin_or_owner?
  end

  def destroy?
    user&.admin_or_owner?
  end
end
