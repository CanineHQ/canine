class RichSelectComponent < ViewComponent::Base
  def initialize(name:, id:, collection:, value_method: :id, selected: nil, partial:,
                 placeholder: "Select an option", disabled: [], data: {})
    @name = name
    @id = id
    @collection = collection
    @value_method = value_method
    @selected = selected
    @partial = partial
    @placeholder = placeholder
    @disabled = Array(disabled).map(&:to_s)
    @data = data
  end

  def selected_item
    @collection.find { |item| item.send(@value_method).to_s == @selected.to_s }
  end

  def disabled?(item)
    @disabled.include?(item.send(@value_method).to_s)
  end

  def select_data_attributes
    @data.map { |k, v| "data-#{k}=\"#{v}\"" }.join(" ").html_safe
  end
end
