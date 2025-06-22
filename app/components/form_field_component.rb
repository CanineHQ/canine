class FormFieldComponent < ViewComponent::Base
  def initialize(label:, description: nil)
    @label = label
    @description = description
  end
end
