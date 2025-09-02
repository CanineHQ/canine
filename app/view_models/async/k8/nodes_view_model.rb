class Async::K8::NodesViewModel < Async::BaseViewModel
  include MetricsHelper
  include StorageHelper
  expects :cluster_id

  def cluster
    @cluster ||= current_user.clusters.find(params[:cluster_id])
  end

  def nodes
    @nodes ||= K8::Metrics::Api::Node.ls(K8::Connection.new(cluster, current_user))
  end

  def initial_render
    "<div class='loading loading-spinner loading-sm'></div>"
  end


  def async_render
    template = <<-HTML
      <table class="table mt-2 rounded-box" id="order_table" data-component="table">
        <thead>
          <tr>
            <th>
              <span class="text-sm font-medium text-base-content/80">Node Name</span>
            </th>
            <th>
              <span class="text-sm font-medium text-base-content/80">CPU Cores</span>
            </th>
            <th>
              <span class="text-sm font-medium text-base-content/80">
                CPU Usage
              </span>
            </th>
            <th>
              <span class="text-sm font-medium text-base-content/80">
                Memory Capacity
              </span>
            </th>
            <th>
              <span class="text-sm font-medium text-base-content/80">
                Memory Usage
              </span>
            </th>
          </tr>
        </thead>
        <tbody>
          <% nodes.each do |node| %>
            <tr class="cursor-pointer hover:bg-base-200/40">
              <td>
                <div class="flex items-center space-x-3 truncate">
                  <div class="font-medium">
                    <%= node.name %>
                  </div>
                </div>
              </td>
              <td>
                <div class="font-medium">
                  <%= integer_to_compute(node.total_cpu) %>#{' '}
                </div>
              </td>
              <td>
                <div class="font-medium">
                  <%= node.cpu_percent %>%
                </div>
              </td>
              <td>
                <div class="font-medium">
                  <%= integer_to_memory(node.total_memory) %>
                </div>
              </td>
              <td>
                <div class="font-medium">
                  <%= node.memory_percent %>%
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>

      <table class="table mt-2 rounded-box" data-component="table">
        <thead>
          <tr>
            <th>
              <span class="text-sm font-medium text-base-content/80">Namespace</span>
            </th>
            <th>
              <span class="text-sm font-medium text-base-content/80">Pod Name</span>
            </th>
            <th>
              <span class="text-sm font-medium text-base-content/80">CPU</span>
            </th>
            <th>
              <span class="text-sm font-medium text-base-content/80">
                Memory
              </span>
            </th>
          </tr>
        </thead>
        <tbody>
          <% nodes.each do |node| %>
            <% node.namespaces.each do |namespace, pods| %>
              <% pods.each do |pod| %>
                <tr class="cursor-pointer hover:bg-base-200/40">
                  <td>
                    <div class="flex items-center space-x-3 truncate font-medium">
                      <%= namespace %>
                    </div>
                  </td>
                  <td>
                    <div class="flex items-center space-x-3 truncate font-medium">
                      <%= pod.name %>
                    </div>
                  </td>
                  <td>
                    <div class="font-medium">
                      <%= integer_to_compute(pod.cpu) %>#{' '}
                    </div>
                  </td>
                  <td>
                    <div class="font-medium">
                      <%= integer_to_memory(pod.memory) %>
                    </div>
                  </td>
                </tr>
              <% end %>
            <% end %>
          <% end %>
        </tbody>
      </table>
    HTML

    ERB.new(template).result(binding)
  end
end
