class RadioSelectCardComponent < ViewComponent::Base
  def initialize(name:, value:, checked:)
    @name = name
    @value = value
    @checked = checked
  end
end
