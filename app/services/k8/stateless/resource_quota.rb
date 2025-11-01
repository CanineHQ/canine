class K8::Stateless::ResourceQuota < K8::Base
  attr_accessor :constrainable

  def initialize(constrainable)
    @constrainable = constrainable
  end
end
