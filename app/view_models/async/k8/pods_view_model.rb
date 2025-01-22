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
        <%= render "processes/pods", pods: pods, parent: add_on %>
      <% end %>
    HTML

    ERB.new(template).result(binding)
  end
end
