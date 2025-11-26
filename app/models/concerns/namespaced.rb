module Namespaced
  def name_is_unique_to_cluster
    if cluster.namespaces.include?(namespace)
      errors.add(:name, "must be unique to this cluster")
    end
  end

  def self.included(base)
    base.class_eval do
      validates_presence_of :namespace

      validate :name_is_unique_to_cluster, on: :create
    end
  end
end
