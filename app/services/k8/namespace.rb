class K8::Namespace < K8::Base
  attr_accessor :nameable

  def initialize(nameable)
    @nameable = nameable
  end
end
