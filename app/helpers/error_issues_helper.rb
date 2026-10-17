module ErrorIssuesHelper
  # Sentry platform values whose devicon has a different name; as, cfml and other have no icon.
  PLATFORM_ICON_ALIASES = { "node" => "nodejs", "cocoa" => "apple", "objc" => "apple", "native" => "cplusplus" }.freeze

  # The devicon logo of the SDK platform an issue came from, or nothing for platforms without one.
  def error_platform_icon(platform)
    return if platform.blank? || %w[as cfml other].include?(platform)

    tag.iconify_icon(icon: "devicon:#{PLATFORM_ICON_ALIASES.fetch(platform, platform)}", width: 14, height: 14, title: platform)
  end
end
