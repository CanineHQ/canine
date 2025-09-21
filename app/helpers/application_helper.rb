module ApplicationHelper
  include Pagy::Frontend

  def custom_pagy_nav(pagy)
    html = '<div class="join">'
    html << pagy_nav_prev(pagy) if pagy.prev
    pagy.series.each do |item|
      html << link_to(item, url_for(page: item), class: "btn btn-primary join-item btn-active btn-sm")
    end
    html << pagy_nav_next(pagy) if pagy.next
    html << "</div>"

    html.html_safe
  end

  def pagy_nav_prev(pagy)
    '<a aria-label="pagination-prev" class="btn join-item btn-sm gap-2" href="' + pagy_url_for(pagy, pagy.prev) + '">' +
    '<iconify-icon icon="lucide:chevron-left" height="16"></iconify-icon>' +
    "</a>"
  end

  def pagy_nav_next(pagy)
    '<a aria-label="pagination-prev" class="btn join-item btn-sm gap-2" href="' + pagy_url_for(pagy, pagy.next) + '">' +
    '<iconify-icon icon="lucide:chevron-right" height="16"></iconify-icon>' +
    "</a>"
  end

  def in_namespace?(namespace)
    controller.controller_path.include?(namespace)
  end

  def letter_to_color(letter)
    colors = [
      '#8B5CF6', # Violet-500
      '#3B82F6', # Blue-500
      '#06B6D4', # Cyan-500
      '#10B981', # Emerald-500
      '#F59E0B', # Amber-500
      '#EF4444', # Red-500
      '#EC4899', # Pink-500
      '#6366F1', # Indigo-500
      '#14B8A6', # Teal-500
      '#84CC16', # Lime-500
      '#F97316', # Orange-500
      '#A855F7', # Purple-500
      '#0EA5E9', # Sky-500
      '#22C55E', # Green-500
      '#FACC15', # Yellow-500
      '#DC2626', # Rose-600
      '#7C3AED', # Violet-600
      '#2563EB', # Blue-600
      '#0891B2', # Cyan-600
      '#059669', # Emerald-600
      '#D97706', # Amber-600
      '#BE185D', # Pink-700
      '#4F46E5', # Indigo-600
      '#0D9488', # Teal-600
      '#65A30D', # Lime-600
      '#EA580C'  # Orange-600
    ]

    index = letter.upcase.ord - 'A'.ord
    colors[index % colors.length]
  end
end
