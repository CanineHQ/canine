module AgentLoop
  # Tidies a session's timeline in batches. Models tend to give each step its own intent ("Find Slack search box",
  # "Find Slack search input", "Paste query"...), which would make every call its own activity. So once a few
  # activities have finished (and when the session ends), one model call reads them, groups consecutive ones that
  # serve the same goal, and gives each group a title and a one-line outcome. Each group is merged into its first
  # activity. The last tidied activity is included, so a goal that spans two batches stays one.
  module Tidy
    BATCH = 5  # tidy once this many activities have finished (and whatever is left when the session ends)
    MAX = 30   # activities per model call

    PROMPT = <<~PROMPT
      You organize an AI agent's work log for the person who reviews it. You get a list of consecutive activities,
      each with an id, the agent's intent, its narration and its actions. Group consecutive activities that serve the
      same goal: a goal is something the person would care about ("Searching Slack for today's messages", "Reading
      Dan's thread", "Opening a draft PR"), not a single step ("Finding the search box", "Pasting the query"), so most
      groups hold several activities. Reply with only a JSON object {"groups": [...]}, in order, every id in exactly
      one group, each group:
        ids: the activity ids in it (consecutive)
        title: what the agent was doing, 2 to 6 words, starting with a verb in -ing form
        outcome: one short sentence on how it ended, with the useful fact ("No #feature-requests channel exists",
                 "Found 3 new messages", "Opened draft PR #483"); empty if it ended unremarkably
    PROMPT

    # Called by AgentSessionActivity#finish! and AgentSession#finish!: enqueue a tidy when there's a batch to do
    def self.enqueue(session, all: false)
      waiting = session.activities.unscope(:order).where(tidied_at: nil).where.not(finished_at: nil).count
      AgentSessions::TidyActivitiesJob.perform_later(session) if all || waiting >= BATCH
    end

    def self.call(session)
      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")
      return unless key

      loop do
        batch = session.activities.where(tidied_at: nil).where.not(finished_at: nil).limit(MAX).to_a
        break if batch.empty?

        previous = session.activities.where.not(tidied_at: nil).where(position: ...batch.first.position).last
        tidy_batch(session, key, [ previous, *batch ].compact, batch)
      end
      session.broadcast_timeline
    end

    def self.tidy_batch(session, key, activities, batch)
      groups = ask(session, key, activities)
      groups = activities.map { |a| { "ids" => [ a.id ] } } unless valid?(groups, activities)
      groups.each do |group|
        members = activities.select { |a| group["ids"].include?(a.id) }
        first = members.first
        first.update!(title: group["title"].presence&.truncate(120) || first.title, outcome: group["outcome"].presence || first.outcome,
                      tidied_at: Time.current)
        members.drop(1).each { |other| merge(other, into: first) }
      end
    ensure
      AgentSessionActivity.where(id: batch.map(&:id)).update_all(tidied_at: Time.current) # never retry a batch forever
    end

    def self.ask(session, key, activities)
      reply = Llm::OpenRouter.new(key.api_key).chat(
        model: session.model, response_format: { type: "json_object" },
        messages: [ { role: "system", content: PROMPT },
                    { role: "user", content: activities.map { |a| describe(a) }.join("\n") } ]
      )
      session.update!(cost_usd: session.cost_usd + reply.usage[:cost_usd])
      JSON.parse(reply.message["content"].to_s[/\{.*\}/m] || "{}")["groups"]
    rescue Llm::OpenRouter::Error, JSON::ParserError => e
      Rails.logger.info("Couldn't tidy session #{session.id}: #{e.message}") # each activity keeps its intent as its title
      nil
    end

    # Every id once, in order, so groups are runs of consecutive activities
    def self.valid?(groups, activities)
      groups.is_a?(Array) && groups.all? { |g| g.is_a?(Hash) && g["ids"].is_a?(Array) } &&
        groups.flat_map { |g| g["ids"] } == activities.map(&:id)
    end

    def self.describe(activity)
      actions = activity.actions.reject(&:look_only?).first(8).map do |action|
        "  - #{action.label} [#{action.status}]: #{action.result.to_h["text"].to_s.squish.truncate(150)}"
      end
      <<~TEXT
        id #{activity.id}#{" (already titled: #{activity.title})" if activity.tidied_at}
          intent: #{activity.intent}
          narration: #{activity.description.to_s.squish.truncate(300).presence || "(none)"}
        #{actions.join("\n").presence || "  (only looked at the screen)"}
      TEXT
    end

    def self.merge(activity, into:)
      activity.actions.update_all(agent_session_activity_id: into.id)
      into.update!(finished_at: [ into.finished_at, activity.finished_at ].compact.max,
                   description: [ into.description, activity.description ].compact.join("\n\n").truncate(4000).presence)
      activity.actions.reset # they belong to `into` now: don't let destroy! delete them from a stale list
      activity.destroy!
      activity.broadcast_remove_to activity.session
    end
  end
end
