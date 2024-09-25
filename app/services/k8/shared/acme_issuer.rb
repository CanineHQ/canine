class K8::Shared::AcmeIssuer < K8::Base
  attr_accessor :email

  def initialize(email)
    @email = email
  end
end