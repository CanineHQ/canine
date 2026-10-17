module ErrorIssuesHelper
  # Sentry platform values whose devicon has a different name; as, cfml and other have no icon.
  PLATFORM_ICON_ALIASES = { "node" => "nodejs", "cocoa" => "apple", "objc" => "apple", "native" => "cplusplus" }.freeze

  # The devicon logo of the SDK platform an issue came from, or nothing for platforms without one.
  def error_platform_icon(platform)
    return if platform.blank? || %w[as cfml other].include?(platform)

    tag.iconify_icon(icon: "devicon:#{PLATFORM_ICON_ALIASES.fetch(platform, platform)}", width: 14, height: 14, title: platform)
  end

  # A compact relative time for dense lists: "now", "5m", "14h", "3d", "2mo", "1y".
  def short_time_ago(time)
    seconds = (Time.current - time).to_i
    return "now" if seconds < 60

    { "y" => 1.year, "mo" => 1.month, "d" => 1.day, "h" => 1.hour, "m" => 1.minute }.each do |unit, length|
      return "#{seconds / length.to_i}#{unit}" if seconds >= length
    end
  end
end
