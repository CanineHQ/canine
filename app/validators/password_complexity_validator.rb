class PasswordComplexityValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    record.errors.add(attribute, "must include at least one uppercase letter") unless value.match?(/[A-Z]/)
    record.errors.add(attribute, "must include at least one lowercase letter") unless value.match?(/[a-z]/)
    record.errors.add(attribute, "must include at least one digit") unless value.match?(/\d/)
    record.errors.add(attribute, "must include at least one special character") unless value.match?(/[^A-Za-z0-9]/)
  end
end
