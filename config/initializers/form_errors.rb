ActionView::Base.field_error_proc = proc do |html_tag, instance|
  # This is the default Rails error wrapper, but it's not nice
  # html = %(<div class="field_with_errors">#{html_tag}</div>).html_safe

  html = ""

  form_fields = [
    "textarea",
    "input",
    "select"
  ]

  elements = Nokogiri::HTML::DocumentFragment.parse(html_tag).css "label, " + form_fields.join(", ")
  elements.each do |e|
    if form_fields.include? e.node_name
      # Add the error class directly to the element
      e.add_class("error")

      html = if e.get_attribute("type") == "checkbox"
        # Checkboxes can't have a border, so we'll need to skip these for now unless we make them more complicated
        e.to_s

      elsif instance.error_message.respond_to? :each
        # Add a hint error after the field
        # If there were multiple errors on an element, we'll combine them into one string
        %(#{e}<p class="form-hint error">&nbsp;#{instance.object.class.human_attribute_name(instance.send(:sanitized_method_name))} #{instance.error_message.uniq.to_sentence}</p>)

      else
        # Add a hint error after the field
        %(#{e}<p class="form-hint error">&nbsp;#{instance.object.class.human_attribute_name(instance.send(:sanitized_method_name))} #{instance.error_message}</p>)
      end

    # Labels
    # if e.node_name.eql? "label"
    #   html = %(<div class="control-group error">#{e}</div>).html_safe

    else
      # For everything else, we'll ignore the error styling
      html = e.to_s
    end
  end

  html.html_safe
end
