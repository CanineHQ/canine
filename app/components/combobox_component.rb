class ComboboxComponent < ViewComponent::Base
  # @param form [ActionView::Helpers::FormBuilder] The form builder
  # @param field [Symbol] The field name for the hidden input
  # @param items [Array<Hash>] Array of items with :id, :partial (optional), :locals (optional), :display_text, :search_text (optional)
  # @param placeholder [String] Placeholder text for the input
  # @param input_class [String] Additional CSS classes for the input
  # @param selected_value [String, Integer, nil] The currently selected value
  def initialize(form:, field:, items:, placeholder: "Search...", input_class: "", selected_value: nil)
    @form = form
    @field = field
    @items = items
    @placeholder = placeholder
    @input_class = input_class
    @selected_value = selected_value
  end

  attr_reader :form, :field, :items, :placeholder, :input_class, :selected_value
end
