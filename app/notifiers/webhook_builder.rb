class WebhookBuilder
  def initialize
    @title = nil
    @description = nil
    @url = nil
    @color = nil
    @widgets = []
  end

  def title(value)
    @title = value
    self
  end

  def description(value)
    @description = value
    self
  end

  def url(value, label: "View Details")
    @url = value
    @url_label = label
    self
  end

  def color(success: nil, in_progress: nil, failed: nil)
    @color = { success: success, in_progress: in_progress, failed: failed }
    self
  end

  def status(emoji:, text:, state:)
    @status_emoji = emoji
    @status_text = text
    @status_state = state
    self
  end

  def widget(label:, value:, link: nil)
    @widgets << { label: label, value: value, link: link }
    self
  end

  def build(provider)
    case provider.to_sym
    when :slack
      slack_payload
    when :discord
      discord_payload
    when :microsoft_teams
      microsoft_teams_payload
    when :google_chat
      google_chat_payload
    else
      raise ArgumentError, "Unknown provider: #{provider}"
    end
  end

  private

  def slack_payload
    fields = @widgets.map do |w|
      value = w[:link] ? "<#{w[:link]}|#{w[:value]}>" : w[:value]
      { title: w[:label], value: value, short: w[:value].to_s.length < 30 }
    end

    attachment = {
      color: slack_color,
      text: @description,
      fields: fields,
      footer: "Canine",
      ts: Time.current.to_i
    }

    attachment[:actions] = [ { type: "button", text: @url_label, url: @url } ] if @url

    {
      text: "#{@status_emoji} *#{@title}*",
      attachments: [ attachment ]
    }
  end

  def discord_payload
    fields = @widgets.map do |w|
      value = w[:link] ? "[#{w[:value]}](#{w[:link]})" : w[:value]
      { name: w[:label], value: value, inline: w[:value].to_s.length < 30 }
    end

    embed = {
      title: "#{@status_emoji} #{@title}",
      description: @description,
      color: discord_color,
      fields: fields,
      timestamp: Time.current.iso8601
    }

    embed[:url] = @url if @url

    { embeds: [ embed ] }
  end

  def microsoft_teams_payload
    facts = @widgets.map do |w|
      value = w[:link] ? "[#{w[:value]}](#{w[:link]})" : w[:value]
      { name: w[:label], value: value }
    end

    payload = {
      "@type": "MessageCard",
      "@context": "http://schema.org/extensions",
      themeColor: teams_color,
      summary: "#{@title} - #{@status_text}",
      sections: [
        {
          activityTitle: "#{@status_emoji} #{@title}",
          activitySubtitle: @description,
          facts: facts,
          markdown: true
        }
      ]
    }

    if @url
      payload[:potentialAction] = [
        {
          "@type": "OpenUri",
          name: @url_label,
          targets: [ { os: "default", uri: @url } ]
        }
      ]
    end

    payload
  end

  def google_chat_payload
    widgets = @widgets.map do |w|
      widget = {
        decoratedText: {
          topLabel: w[:label],
          text: w[:value]
        }
      }
      widget[:decoratedText][:onClick] = { openLink: { url: w[:link] } } if w[:link]
      widget
    end

    if @url
      widgets << {
        buttonList: {
          buttons: [
            {
              text: @url_label,
              onClick: { openLink: { url: @url } }
            }
          ]
        }
      }
    end

    {
      cardsV2: [
        {
          cardId: "notification-#{Time.current.to_i}",
          card: {
            header: {
              title: @title,
              subtitle: @description
            },
            sections: [ { widgets: widgets } ]
          }
        }
      ]
    }
  end

  def slack_color
    case @status_state
    when :success then "good"
    when :in_progress then "#3B82F6"
    else "danger"
    end
  end

  def discord_color
    case @status_state
    when :success then 0x22C55E
    when :in_progress then 0x3B82F6
    else 0xEF4444
    end
  end

  def teams_color
    case @status_state
    when :success then "22C55E"
    when :in_progress then "3B82F6"
    else "EF4444"
    end
  end
end
