module AddOnsHelper
  def add_on_layout(add_on, &block)
    render layout: 'add_ons/layout', locals: { add_on: }, &block
  end

  def flatten_hash(hash, parent_key = '', result = {})
    hash.each do |key, value|
      new_key = parent_key.empty? ? key.to_s : "#{parent_key}.#{key}"
      if value.is_a?(Hash)
        flatten_hash(value, new_key, result)
      else
        result[new_key] = value
      end
    end
    result
  end

  def get_logo_image_url(logo_image_id)
    logo_image_id ? "https://artifacthub.io/image/#{logo_image_id}" : "https://artifacthub.io/static/media/placeholder_pkg_helm.png"
  end
end
