module SettingsHelper
  def settings_layout(&block)
    render layout: 'settings/layout', &block
  end
end
