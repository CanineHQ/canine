require 'rails_helper'
RSpec.shared_context 'with stubbed portainer' do
  before do
    user = User.first || create(:user)
    if Cluster.count.zero?
      create(:cluster, kubeconfig: nil)
    else
      Cluster.last.update(kubeconfig: nil)
    end
    create(:provider, provider: 'portainer', access_token: 'jwt', user:)
    account = if user.accounts.count.zero?
      create(:account, owner: user)
    else
      user.accounts.first
    end
    create(:stack_manager, account:)

    allow(Portainer::Client).to receive(:new).and_return(double(get_kubernetes_config: 'kubeconfig'))
  end
end
