# Extend ActionView::Helpers::FormBuilder with custom form helpers
ActionView::Helpers::FormBuilder.class_eval do
  def combobox(field, items, options = {})
    @template.render(ComboboxComponent.new(
      form: self,
      field: field,
      items: items,
      placeholder: options[:placeholder] || "Search...",
      input_class: options[:input_class] || "",
      selected_value: options[:selected_value] || object&.public_send(field)
    ))
  end
end
