# frozen_string_literal: true

class ClusterPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    visible_to_user?
  end

  def create?
    true
  end

  def update?
    visible_to_user?
  end

  def destroy?
    visible_to_user?
  end

  private

  def visible_to_user?
    result = Clusters::VisibleToUser.execute(account_user: user)
    result.clusters.exists?(id: record.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      result = Clusters::VisibleToUser.execute(account_user: user)
      result.clusters
    end
  end
end
