module Namespaced
  RESERVED_NAMESPACES = [
    "default",
    "kube-system",
    "kube-public",
    "kube-node-lease",
    "kube-flannel",
    "canine-system"
  ]

  def name_is_unique_to_cluster
    if cluster.namespaces.include?(namespace)
      errors.add(:name, "must be unique to this cluster")
    end
  end

  def name_and_namespace_not_reserved
    errors.add(:name, "is a reserved keyword and cannot be used") if RESERVED_NAMESPACES.include?(name)
    errors.add(:namespace, "is a reserved keyword and cannot be used") if RESERVED_NAMESPACES.include?(namespace)
  end

  def self.included(base)
    base.class_eval do
      validates_presence_of :namespace

      validate :name_is_unique_to_cluster, on: :create
      validate :name_and_namespace_not_reserved
    end
  end
end
