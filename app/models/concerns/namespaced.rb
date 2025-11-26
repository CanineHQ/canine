module Namespaced
  def self.included(base)
    base.class_eval do
      validates_presence_of :namespace
    end
  end
end
