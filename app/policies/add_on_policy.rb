# frozen_string_literal: true

class AddOnPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    user_owns_cluster?
  end

  def create?
    user_owns_cluster?
  end

  def update?
    user_owns_cluster?
  end

  def destroy?
    user_owns_cluster?
  end

  def restart?
    user_owns_cluster?
  end

  def download_values?
    user_owns_cluster?
  end

  private

  def user_owns_cluster?
    user.clusters.exists?(id: record.cluster_id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:cluster).where(clusters: { account_id: user.accounts.select(:id) })
    end
  end
end
