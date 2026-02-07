class Async::Helm::ValuesYamlViewModel < Async::BaseViewModel
  include AddOnsHelper
  expects :add_on_id

  def service
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
    connection = K8::Connection.new(@add_on, current_user)
    @service ||= K8::Helm::Service.new(connection)
  end

  def initial_render
    render "shared/components/table_skeleton", locals: { columns: 2 }
  end

  def async_render
    template = <<-HTML
      <table class="table">
        <thead>
          <tr>
            <th>Key</th>
            <th>Value</th>
          </tr>
        </thead>
        <tbody>
          <% flatten_hash(service.values_yaml).each do |key, value| %>
            <tr>
              <td><%= key %></td>
              <td>
                <div class="flex flex-row items-center" data-controller="toggle-password" data-toggle-password-mask-length-value="true">
                  <input type="password" readonly class="input input-sm w-full bg-transparent border-none focus:outline-none" value="<%= value %>" data-toggle-password-target="input">
                  <button class="btn btn-sm btn-ghost" type="button" data-action="click->toggle-password#toggle">
                    <iconify-icon icon="lucide:eye" data-toggle-password-target="icon"></iconify-icon>
                  </button>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    HTML

    ERB.new(template).result(binding)
  end
end
