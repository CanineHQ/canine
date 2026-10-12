# frozen_string_literal: true

# Collects recent logs and events for every pod in a namespace.
class K8::PodLogs
  MAX_TAIL_LINES = 500

  def initialize(client, namespace)
    @client = client
    @namespace = namespace
  end

  def self.for_project(project, user, tail_lines: 100)
    client = K8::Client.new(K8::Connection.new(project, user))
    new(client, project.namespace).fetch(client.pods_for_namespace(project.namespace), tail_lines:, with_service_name: true)
  end

  def self.for_add_on(add_on, user, tail_lines: 100)
    client = K8::Client.new(K8::Connection.new(add_on.cluster, user))
    new(client, add_on.name).fetch(client.get_pods(namespace: add_on.name), tail_lines:)
  end

  def fetch(pods, tail_lines: 100, with_service_name: false)
    tail_lines = [ tail_lines.to_i, MAX_TAIL_LINES ].min
    tail_lines = 100 unless tail_lines.positive?

    pods.map do |pod|
      pod_name = pod.metadata.name
      service_name = (pod.metadata.labels&.app || pod_name.split("-").first) if with_service_name

      Api::Pods::LogViewModel.new(
        pod,
        logs: pod_logs(pod_name, tail_lines),
        events: pod_events(pod_name),
        service_name: service_name
      ).as_json
    end
  end

  private

  def pod_logs(pod_name, tail_lines)
    @client.get_pod_log(pod_name, @namespace, tail_lines: tail_lines)
  rescue Kubeclient::HttpError => e
    "Error fetching logs: #{e.message}"
  end

  def pod_events(pod_name)
    @client.get_pod_events(pod_name, @namespace).map do |event|
      Api::Pods::EventViewModel.new(event).as_json
    end
  rescue Kubeclient::HttpError => e
    [ { error: "Error fetching events: #{e.message}" } ]
  end
end
