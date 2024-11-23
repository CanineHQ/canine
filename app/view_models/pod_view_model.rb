class PodViewModel
  include Rails.application.routes.url_helpers

  attr_reader :parent, :pod
  def initialize(parent, pod)
    @parent = parent
    @pod = pod
  end

  def show_pod_logs_path
    if parent.is_a?(Project)
      project_process_path(parent, pod.metadata.name)
    elsif parent.is_a?(AddOn)
      add_on_process_path(parent, pod.metadata.name)
    end
  end

  def show_delete_pod_path?
    parent.is_a?(Project)
  end

  def delete_pod_path
    if parent.is_a?(Project)
      project_process_path(parent, pod.metadata.name)
    end
  end

  def status
    @status ||= if pod.status.phase == "Failed"
      :failed
    elsif pod.status.phase == "Pending"
      :pending
    elsif pod.status.containerStatuses.first.state.respond_to?(:waiting)
      :waiting
    elsif pod.status.containerStatuses.first.state.respond_to?(:terminated)
      :terminated
    elsif pod.status.containerStatuses.first.state.respond_to?(:running)
      :running
    end
  end

  def message
    pod.status.message || pod.status.conditions&.first&.message || pod.status.containerStatuses&.first&.state&.waiting&.message
  end

  def reason
    pod.status.containerStatuses.first.state.waiting.reason
  end
end
