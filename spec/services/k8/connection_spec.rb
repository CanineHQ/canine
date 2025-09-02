require 'rails_helper'
require 'support/shared_contexts/with_portainer'

RSpec.describe K8::Connection do
  let(:user) { create(:user) }
  let(:cluster) { create(:cluster) }
  let(:project) { create(:project, cluster: cluster) }
  let(:add_on) { create(:add_on, cluster: cluster) }

  describe '#initialize' do
    it 'accepts a clusterable and user' do
      connection = described_class.new(cluster, user)
      expect(connection.clusterable).to eq(cluster)
      expect(connection.user).to eq(user)
    end
  end

  describe '#cluster' do
    context 'when clusterable is a Cluster' do
      let(:connection) { described_class.new(cluster, user) }

      it 'returns the cluster itself' do
        expect(connection.cluster).to eq(cluster)
      end
    end

    context 'when clusterable is a Project' do
      let(:connection) { described_class.new(project, user) }

      it 'returns the project cluster' do
        expect(connection.cluster).to eq(cluster)
      end
    end

    context 'when clusterable is an AddOn' do
      let(:connection) { described_class.new(add_on, user) }

      it 'returns the add_on cluster' do
        expect(connection.cluster).to eq(cluster)
      end
    end

    context 'when clusterable is an unsupported type' do
      let(:connection) { described_class.new(user, user) }

      it 'raises an error' do
        expect { connection.cluster }.to raise_error(RuntimeError, '`clusterable` is not a Cluster, Project, or AddOn')
      end
    end
  end

  describe '#kubeconfig' do
    context 'when clusterable is a Cluster' do
      let(:connection) { described_class.new(cluster, user) }

      it 'returns the cluster kubeconfig' do
        expect(connection.kubeconfig).to eq(cluster.kubeconfig)
      end
    end

    context 'when clusterable is a Project' do
      let(:connection) { described_class.new(project, user) }

      it 'returns the kubeconfig from the project cluster' do
        expect(connection.kubeconfig).to eq(cluster.kubeconfig)
      end
    end

    context 'when clusterable is an AddOn' do
      let(:connection) { described_class.new(add_on, user) }

      it 'returns the kubeconfig from the add_on cluster' do
        expect(connection.kubeconfig).to eq(cluster.kubeconfig)
      end
    end
  end

  describe 'using the K8Stack' do
    context 'kubernetes provider is portainer' do
      include_context 'with portainer'
      let!(:cluster) { create(:cluster, kubeconfig: nil) }
      let(:account) { create(:account, owner: user) }

      before do
        create(:provider, provider: 'portainer', access_token: 'jwt', user:)
        create(:stack_manager, account:)
      end

      it 'returns the kubeconfig' do
        connection = described_class.new(cluster, user)
        expect(connection.kubeconfig).to eq(JSON.parse(File.read(Rails.root.join(*%w[spec resources portainer kubeconfig.json]))))
      end
    end
  end

  describe 'dynamic accessor methods' do
    describe '#add_on' do
      context 'when clusterable is an AddOn' do
        let(:connection) { described_class.new(add_on, user) }

        it 'returns the add_on' do
          expect(connection.add_on).to eq(add_on)
        end
      end

      context 'when clusterable is not an AddOn' do
        let(:connection) { described_class.new(cluster, user) }

        it 'raises an error' do
          expect { connection.add_on }.to raise_error(RuntimeError, '`clusterable` is not a AddOn')
        end
      end

      context 'when clusterable is a Project' do
        let(:connection) { described_class.new(project, user) }

        it 'raises an error' do
          expect { connection.add_on }.to raise_error(RuntimeError, '`clusterable` is not a AddOn')
        end
      end
    end

    describe '#project' do
      context 'when clusterable is a Project' do
        let(:connection) { described_class.new(project, user) }

        it 'returns the project' do
          expect(connection.project).to eq(project)
        end
      end

      context 'when clusterable is not a Project' do
        let(:connection) { described_class.new(cluster, user) }

        it 'raises an error' do
          expect { connection.project }.to raise_error(RuntimeError, '`clusterable` is not a Project')
        end
      end

      context 'when clusterable is an AddOn' do
        let(:connection) { described_class.new(add_on, user) }

        it 'raises an error' do
          expect { connection.project }.to raise_error(RuntimeError, '`clusterable` is not a Project')
        end
      end
    end
  end

  describe 'attribute readers' do
    let(:connection) { described_class.new(cluster, user) }

    it 'provides access to clusterable' do
      expect(connection.clusterable).to eq(cluster)
    end

    it 'provides access to user' do
      expect(connection.user).to eq(user)
    end
  end

  describe 'edge cases' do
    context 'when clusterable is nil' do
      let(:connection) { described_class.new(nil, user) }

      it 'stores nil as clusterable' do
        expect(connection.clusterable).to be_nil
      end

      it 'raises error when accessing cluster' do
        expect { connection.cluster }.to raise_error(RuntimeError, '`clusterable` is not a Cluster, Project, or AddOn')
      end

      it 'raises error when accessing dynamic methods' do
        expect { connection.project }.to raise_error(RuntimeError)
        expect { connection.add_on }.to raise_error(RuntimeError)
      end
    end

    context 'when user is nil' do
      let(:connection) { described_class.new(cluster, nil) }

      it 'stores nil as user' do
        expect(connection.user).to be_nil
      end

      it 'can still access cluster methods' do
        expect(connection.cluster).to eq(cluster)
      end
    end
  end
end
