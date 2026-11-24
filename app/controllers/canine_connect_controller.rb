class CanineConnectController < ApplicationController
  def show
    @clusters = ::Clusters::VisibleToUser.execute(account_user: current_account_user).clusters.includes(:cluster_packages).order(:name)
  end
end
