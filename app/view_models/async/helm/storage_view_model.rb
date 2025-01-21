class Async::Helm::StorageViewModel < Async::BaseViewModel
  attr_reader :add_on, :service
  expects :add_on_id

  def add_on
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
  end

  def service
    @service ||= K8::Helm::Service.new(add_on)
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm text-lg'></div>"
  end

  def render_error
    "<div class='text-yellow-500'>Error fetching storage metrics, pods might not be ready yet.</div>"
  end

  def async_render
    template = <<-HTML
      <div class="mb-4">
        <% if service.storage_metrics.any? %>
          <% service.storage_metrics.each do |metric| %>
            <div>Volume: <pre class="inline"><%= metric[:name] %></pre></div>
            <% if metric[:usage] %>
              <div><strong><%= metric[:usage][:use_percentage] %>%</strong> used out of <strong><%= standardize_size(metric[:usage][:available]) %>B</strong></div>
              <progress class="progress w-56" value="<%= metric[:usage][:use_percentage] %>" max="100"></progress>
            <% end %>
          <% end %>
        <% else %>
          <div class="text-gray-500">No storage volumes found</div>
        <% end %>
      </div>
    HTML

    ERB.new(template).result(binding)
  end
end
