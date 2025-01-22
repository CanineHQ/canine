class Async::K8::PodsViewModel < Async::BaseViewModel
  include LogColorsHelper
  expects :add_on_id

  def add_on
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
  end

  def pods
    @pods ||= begin
      client = K8::Client.new(add_on.cluster.kubeconfig).client
      client.get_pods(namespace: add_on.name)
    end
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm'></div>"
  end


  def async_render
    template = <<-HTML
      <% if pods.empty? %>
        <div>
          <p class="text-gray-500">Nothing running in this namespace</p>
        </div>
      <% else %>
        <table class="table mt-2 rounded-box" data-component="table">
          <thead>
            <tr>
              <th>
                <span class="text-sm font-medium text-base-content/80">Pod Name</span>
              </th>
              <th>
                <span class="text-sm font-medium text-base-content/80">
                  Status
                </span>
              </th>
              <th>
                <span class="text-sm font-medium text-base-content/80">
                  Message
                </span>
              </th>
              <th>
                <span class="text-sm font-medium text-base-content/80">
                  Created At
                </span>
              </th>
            </tr>
          </thead>
          <tbody>
            <% pods.each do |pod| %>
              <% view_model = PodViewModel.new(add_on, pod) %>
              <tr class="hover:bg-base-200/40">
                <td>
                  <div class="flex items-center space-x-3 truncate">
                    <div class="font-medium">
                      <%= view_model.pod.metadata.name %>
                    </div>
                  </div>
                </td>
                <td>
                  <div class="font-medium">
                    <% if view_model.status == :waiting %>
                      <div class="text-error"><%= view_model.reason %></div>
                    <% elsif view_model.status == :terminated %>
                      <div class="text-success"><%= view_model.status.to_s.titleize %></div>
                    <% elsif view_model.status == :failed %>
                      <div class="text-error"><%= view_model.status.to_s.titleize %></div>
                    <% else %>
                      <%= view_model.status.to_s.titleize %>
                    <% end %>
                  </div>
                </td>
                <td>
                  <div class="font-medium">
                    <%= view_model.message %>
                  </div>
                </td>
                <td>
                  <div class="font-medium">
                    <%= Time.parse(pod.metadata.creationTimestamp).to_formatted_s(:short) %>
                  </div>
                </td>
                <td>
                  <div class="flex items-center space-x-2">
                    <div class="font-medium">
                      <a href="<%= view_model.show_pod_logs_path %>" class="btn btn-sm btn-outline">Show Logs</a>
                    </div>

                    <div class="font-medium">
                      <% if pod.status.phase == "Running" %>
                        <button
                          class="btn btn-sm btn-outline"
                          data-action="click->processes#showConnectionInstructions"
                          data-pod-name="<%= pod.metadata.name %>"
                          data-namespace="<%= pod.metadata.namespace %>"
                        >Connect</button>
                      <% else %>
                        <div role="tooltip" data-tip="Pod is not running" class="tooltip tooltip-secondary">
                          <button
                            disabled
                            class="btn btn-sm btn-outline btn-disabled"
                          >Connect</button>
                        </div>
                      <% end %>
                    </div>

                    <div class="font-medium">
                      <% if view_model.show_delete_pod_path? %>
                        <% if pod.status.phase != "Running" || pod.metadata.labels.oneoff %>
                          <a href="<%= view_model.delete_pod_path %>" class="btn btn-sm btn-error btn-outline" data-method="delete" rel="nofollow">Delete</a>
                        <% else %>
                          <div role="tooltip" data-tip="Be careful when deleting running pods, it can cause downtime for your project" class="tooltip tooltip-secondary">
                            <a href="<%= view_model.delete_pod_path %>" class="btn btn-sm btn-error btn-outline" data-method="delete" rel="nofollow">Delete</a>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    HTML

    ERB.new(template).result(binding)
  end
end
