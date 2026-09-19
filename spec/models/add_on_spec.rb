# == Schema Information
#
# Table name: add_ons
#
#  id                      :bigint           not null, primary key
#  chart_type              :string
#  chart_url               :string
#  managed_namespace       :boolean          default(TRUE)
#  metadata                :jsonb
#  name                    :string           not null
#  namespace               :string           not null
#  repository_url          :string           not null
#  status                  :integer          default("installing"), not null
#  values                  :jsonb
#  version                 :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  artifact_hub_package_id :string
#  cluster_id              :bigint           not null
#
# Indexes
#
#  index_add_ons_on_cluster_id           (cluster_id)
#  index_add_ons_on_cluster_id_and_name  (cluster_id,name) UNIQUE
#  index_add_ons_on_name                 (name)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
require 'rails_helper'

RSpec.describe AddOn, type: :model do
  let(:cluster) { create(:cluster) }
  let(:add_on) { build(:add_on, cluster:) }

  describe 'validations' do
    context 'when name exists in another cluster within the same account' do
      it 'is not valid' do
        existing_add_on = create(:add_on)
        other_cluster = create(:cluster, account: existing_add_on.cluster.account)
        new_add_on = build(:add_on, name: existing_add_on.name)
        new_add_on.cluster = other_cluster

        expect(new_add_on).not_to be_valid
        expect(new_add_on.errors[:name]).to include("has already been taken")
      end
    end

    context 'when name or namespace is reserved' do
      it 'is not valid when name is reserved' do
        add_on.name = 'canine-system'
        expect(add_on).not_to be_valid
        expect(add_on.errors[:name]).to include("is a reserved keyword and cannot be used")
      end

      it 'is not valid when namespace is reserved' do
        add_on.namespace = 'kube-public'
        expect(add_on).not_to be_valid
        expect(add_on.errors[:namespace]).to include("is a reserved keyword and cannot be used")
      end
    end
  end
end
