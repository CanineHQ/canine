module AvoDashboardHelper
  # Cluster statuses: initializing, installing, running, failed, destroying, deleted
  def status_color_style(status)
    case status.to_s
    when 'running'
      'background-color: #22c55e;'
    when 'initializing', 'installing'
      'background-color: #eab308;'
    when 'failed'
      'background-color: #ef4444;'
    when 'destroying', 'deleted'
      'background-color: #6b7280;'
    else
      'background-color: #9ca3af;'
    end
  end

  # AddOn statuses: installing, installed, uninstalling, uninstalled, failed, updating
  def addon_status_color_style(status)
    case status.to_s
    when 'installed'
      'background-color: #22c55e;'
    when 'installing', 'updating'
      'background-color: #eab308;'
    when 'failed'
      'background-color: #ef4444;'
    when 'uninstalling', 'uninstalled'
      'background-color: #6b7280;'
    else
      'background-color: #9ca3af;'
    end
  end

  # Build statuses: in_progress, completed, failed, killed
  def build_status_color_style(status)
    case status.to_s
    when 'completed'
      'background-color: #22c55e;'
    when 'in_progress'
      'background-color: #eab308;'
    when 'failed'
      'background-color: #ef4444;'
    when 'killed'
      'background-color: #6b7280;'
    else
      'background-color: #9ca3af;'
    end
  end

  def build_status_badge_style(status)
    case status.to_s
    when 'completed'
      'background-color: #dcfce7; color: #166534;'
    when 'in_progress'
      'background-color: #fef9c3; color: #854d0e;'
    when 'failed'
      'background-color: #fee2e2; color: #991b1b;'
    when 'killed'
      'background-color: #f3f4f6; color: #374151;'
    else
      'background-color: #f3f4f6; color: #374151;'
    end
  end

  # Deployment statuses: in_progress, completed, failed
  def deployment_status_color_style(status)
    case status.to_s
    when 'completed'
      'background-color: #22c55e;'
    when 'in_progress'
      'background-color: #eab308;'
    when 'failed'
      'background-color: #ef4444;'
    else
      'background-color: #9ca3af;'
    end
  end

  def deployment_status_badge_style(status)
    case status.to_s
    when 'completed'
      'background-color: #dcfce7; color: #166534;'
    when 'in_progress'
      'background-color: #fef9c3; color: #854d0e;'
    when 'failed'
      'background-color: #fee2e2; color: #991b1b;'
    else
      'background-color: #f3f4f6; color: #374151;'
    end
  end
end
