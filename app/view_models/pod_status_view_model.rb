class PodStatusViewModel
  attr_reader :pod
  def initialize(pod)
    @pod = pod
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
    pod.status.message || pod.status.conditions?.first?.message
  end

  def reason
    pod.status.containerStatuses.first.state.waiting.reason
  end

  def message
    pod.status.containerStatuses.first.state.waiting.message
  end
end
