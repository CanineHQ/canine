# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    visible_to_user?
  end

  def create?
    visible_to_user?
  end

  def update?
    visible_to_user?
  end

  def destroy?
    visible_to_user?
  end

  private

  def visible_to_user?
    result = Projects::VisibleToUser.execute(account_user: user)
    result.projects.exists?(id: record.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      result = Projects::VisibleToUser.execute(account_user: user)
      result.projects
    end
  end
end
