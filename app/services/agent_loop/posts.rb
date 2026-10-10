module AgentLoop
  # After a run, the posts for the person's feed (AgentPost): each thing worth telling them (something it did for
  # them, something it found, something it left for them, or a problem), in a sentence or two, in the agent's own
  # voice, linked to the step that did it and shown with its screenshot. A run with nothing new to tell gets none.
  # One model call; writing again replaces the run's posts.
  module Posts
    PROMPT = <<~PROMPT
      You write posts for a person's feed about what their AI agent did for them on their computer, like posts from an
      assistant they trust: they scroll it to catch up. You get the agent's task, its summary of the run, and its work
      log: activities (with ids), each with the screenshots taken during it (with ids). Reply with only a JSON object
      {"posts": [...]}, in the order things happened, each post:
        kind: "done" (it did something for them), "found" (it learned something they'd want to know), "needs_you"
              (it left something for them to decide or do), or "problem" (something went wrong that they should know)
        text: one or two short sentences, first person, past tense, specific (names, numbers, titles, links), e.g.
              "I noticed Sean asked to be added to Persona, so [I added him] as an Editor." Wrap the words that say
              what it did (or found) in [brackets], exactly once: they link to the step that did it.
        activity_id: the activity that did it (the link goes there)
        screenshot_id: the screenshot that best shows it (the result, not the way there), or null if none shows it
      Only what the person cares about: the outcomes of the task, not the setup, navigation, retries or tools used.
      Most runs have 1 to 3 posts; a run that found nothing new and did nothing has none ({"posts": []}). A run that
      failed before doing its job gets one "problem" post saying what stopped it. Never invent anything the log and
      summary don't show.
    PROMPT
    SHOTS_PER_ACTIVITY = 3

    def self.call(session)
      key = session.agent_computer.account.agent_provider_keys.find_by(provider: "openrouter")
      activities = session.activities.includes(actions: { screenshot_attachment: :blob }).to_a
      return if key.nil? || (activities.empty? && session.summary.blank?)

      reply = Llm::OpenRouter.new(key.api_key).chat(
        model: session.model, response_format: { type: "json_object" },
        messages: [ { role: "system", content: PROMPT }, { role: "user", content: log(session, activities) } ]
      )
      session.update!(cost_usd: session.cost_usd + reply.usage[:cost_usd])
      posts = JSON.parse(reply.message["content"].to_s[/\{.*\}/m] || "{}")["posts"]
      save(session, activities, posts) if posts.is_a?(Array)
    rescue Llm::OpenRouter::Error, JSON::ParserError => e
      Rails.logger.info("Couldn't write posts for session #{session.id}: #{e.message}")
    end

    def self.save(session, activities, posts)
      by_id = activities.index_by(&:id)
      shots = activities.flat_map(&:actions).select { |a| a.screenshot.attached? }.index_by(&:id)
      AgentPost.transaction do
        session.posts.delete_all
        posts.grep(Hash).each_with_index do |post, i|
          next if post["text"].blank? || !post["kind"].in?(AgentPost::KINDS)

          activity = by_id[post["activity_id"].to_i]
          # The chosen screenshot if it's one of this run's, else the last one of the step it links to
          shot = shots[post["screenshot_id"].to_i] || activity&.actions&.reverse&.find { |a| a.screenshot.attached? }
          session.posts.create!(agent_computer: session.agent_computer, kind: post["kind"], text: post["text"].to_s.strip.truncate(600),
                                activity:, action: shot, posted_at: session.finished_at || Time.current, position: i)
        end
      end
    end

    def self.log(session, activities)
      task = session.agent_task
      <<~LOG
        Task: #{task&.name} — #{task&.instruction}
        Run: #{session.status}#{" (#{session.error})" if session.error.present?}

        Summary:
        #{session.summary.presence || "(none)"}

        Work log:
        #{activities.map { |a| describe(a) }.join("\n")}
      LOG
    end

    def self.describe(activity)
      shots = activity.actions.select { |a| a.screenshot.attached? }.last(SHOTS_PER_ACTIVITY)
      [ "activity #{activity.id}: #{activity.title}#{" → #{activity.outcome}" if activity.outcome.present?}",
        *shots.map { |a| "  screenshot #{a.id}: after #{a.label}" } ].join("\n")
    end
  end
end
