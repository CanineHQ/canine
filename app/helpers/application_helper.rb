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
end
