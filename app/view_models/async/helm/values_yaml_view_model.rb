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
              <td><%= value %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    HTML

    ERB.new(template).result(binding)
  end
end
