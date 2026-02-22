# == Schema Information
#
# Table name: ingress_endpoints
#
#  id                :bigint           not null, primary key
#  endpoint_name     :string           not null
#  endpointable_type :string           not null
#  port              :integer          default(80), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  endpointable_id   :bigint           not null
#
# Indexes
#
#  index_ingress_endpoints_uniqueness  (endpointable_type,endpointable_id,endpoint_name,port) UNIQUE
#
class IngressEndpoint < ApplicationRecord
  belongs_to :endpointable, polymorphic: true
  has_many :domains, dependent: :destroy

  validates :endpoint_name, presence: true
  validates :port, presence: true, numericality: { greater_than: 0 }
  validates :endpoint_name, uniqueness: { scope: [ :endpointable_type, :endpointable_id, :port ] }

  def cluster
    case endpointable
    when Service then endpointable.project.cluster
    when AddOn then endpointable.cluster
    end
  end

  def namespace
    case endpointable
    when Service then endpointable.project.namespace
    when AddOn then endpointable.namespace
    end
  end
end
