class RadioSelectCardComponent < ViewComponent::Base
  def initialize(name:, value:, checked:, href:)
    @name = name
    @value = value
    @checked = checked
    @href = href
  end
end
