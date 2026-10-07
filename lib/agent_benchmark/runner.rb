module AgentBenchmark
  # Runs the benchmark tasks (tasks.yml) one after another on an agent computer, with a given model, and records how
  # each did: correct (an LLM judge compares the summary with a reference answer), time, turns, tokens and cost.
  #
  #   bin/rails "agent:benchmark[15,openai/gpt-5.1]"   (needs a GoodJob worker running)
  #
  # Results go to tmp/agent_benchmark/<time>-<model>.json and are printed as a table.
  class Runner
    TASKS = YAML.load_file(File.join(__dir__, "tasks.yml"))
    JUDGE_MODEL = "anthropic/claude-sonnet-4.6"
    Result = Struct.new(:key, :session_id, :status, :correct, :reason, :minutes, :turns, :actions, :input_tokens,
                        :cached_tokens, :output_tokens, :cost_usd, keyword_init: true)

    def initialize(computer, model:, only: nil, label: nil)
      @computer = computer
      @model = model
      @label = label
      @tasks = TASKS["tasks"].select { |t| only.blank? || only.include?(t["key"]) }
      @key = computer.account.agent_provider_keys.find_by!(provider: "openrouter").api_key
    end

    def run
      results = @tasks.map { |task| run_one(task) }
      save(results)
      puts table(results)
      results
    end

    private

    def run_one(definition)
      sleep 5 while @computer.agent_sessions.active.exists?
      task = task_for(definition)
      session = AgentSession.start!(task, trigger: :manual, window_from: nil)
      deadline = Time.current + task.spec.dig("limits", "minutes").to_i.minutes + 3.minutes
      sleep 5 while session.reload.active? && Time.current < deadline
      session.finish!(:cancelled, error: "Stopped by the benchmark (over time).") if session.active?
      wait_for_wrapup(session)
      correct, reason = judge(definition, session)
      result = Result.new(key: definition["key"], session_id: session.id, status: session.status, correct:, reason:,
                          minutes: session.started_at ? ((session.finished_at - session.started_at) / 60.0).round(1) : 0.0, turns: session.turns,
                          actions: session.actions.count, input_tokens: session.input_tokens,
                          cached_tokens: session.try(:cached_tokens).to_i, output_tokens: session.output_tokens,
                          cost_usd: session.cost_usd.to_f.round(4))
      puts "#{result.key}: #{result.correct ? "correct" : "WRONG"} (#{result.status}, #{result.minutes} min, #{result.turns} turns, $#{result.cost_usd}) #{reason}"
      result
    end

    # A session that stopped without a summary gets one from AgentSessions::WrapupJob, a few seconds later
    def wait_for_wrapup(session)
      deadline = Time.current + 90.seconds
      sleep 3 while session.reload.summary.blank? && Time.current < deadline &&
                    GoodJob::Job.where(job_class: "AgentSessions::WrapupJob", finished_at: nil).exists?
    end

    # A disabled task per benchmark item, with its hand-written spec and the model under test
    def task_for(definition)
      defaults = TASKS["defaults"]
      task = @computer.agent_tasks.find_or_initialize_by(name: "[benchmark] #{definition["key"]}")
      task.update!(instruction: definition["instruction"], schedule: "0 0 1 1 *", model: @model, enabled: false,
                   spec: { "sources" => definition["sources"], "never" => defaults["never"], "limits" => defaults["limits"],
                           "time_zone" => defaults["time_zone"] })
      task
    end

    def judge(definition, session)
      reference = reference_for(definition["reference"])
      return [ false, "no summary (#{session.error})" ] if session.summary.blank?

      reply = Llm::OpenRouter.new(@key).chat(
        model: JUDGE_MODEL, response_format: { type: "json_object" },
        messages: [ { role: "system", content: <<~PROMPT },
          You grade an AI agent's answer to a task. Compare its summary with the reference. Counts and points may
          differ slightly if the page changed between the agent reading it and the reference being taken. Reply with
          only JSON: {"correct": true or false, "reason": "one short sentence"}.
        PROMPT
                    { role: "user", content: "Task: #{definition["instruction"]}\n\nReference: #{reference}\n\nAgent's summary:\n#{session.summary}" } ]
      )
      json = JSON.parse(reply.message["content"].to_s[/\{.*\}/m] || "{}")
      [ json["correct"] == true, json["reason"].to_s ]
    rescue Llm::OpenRouter::Error, JSON::ParserError => e
      [ false, "judge failed: #{e.message}" ]
    end

    # Live references, from public APIs, taken right after the run
    def reference_for(reference)
      return reference unless reference.to_s.start_with?("live:")

      case reference.delete_prefix("live:")
      when "hn_top_story"
        id = get_json("https://hacker-news.firebaseio.com/v0/topstories.json").first
        item = get_json("https://hacker-news.firebaseio.com/v0/item/#{id}.json")
        "Top story: \"#{item["title"]}\", #{item["score"]} points, #{item["descendants"]} comments (id #{id})"
      when "canine_newest_issue"
        issue = get_json("https://api.github.com/repos/CanineHQ/canine/issues?state=open&sort=created&direction=desc&per_page=100")
                .reject { |i| i["pull_request"] }.first
        "Newest open issue: ##{issue["number"]} \"#{issue["title"]}\" (the repo czhu12/canine redirects to CanineHQ/canine)"
      when "rails_latest_release"
        release = get_json("https://api.github.com/repos/rails/rails/releases/latest")
        "Newest release: #{release["tag_name"]} (#{release["name"]}), published #{release["published_at"]}"
      when "wikipedia_turing_machine"
        summary = get_json("https://en.wikipedia.org/api/rest_v1/page/summary/Turing_machine")
        "The article's first sentence: #{summary["extract"].to_s[/\A.*?\.(?=\s|\z)/m]}"
      end
    rescue StandardError => e
      "(couldn't take the reference: #{e.message})"
    end

    def get_json(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri, { "User-Agent" => "canine-agent-benchmark/1.0" })
      JSON.parse(response.body)
    end

    def save(results)
      dir = Rails.root.join("tmp/agent_benchmark")
      FileUtils.mkdir_p(dir)
      name = "#{Time.current.strftime("%Y%m%d-%H%M")}-#{@label || @model.tr("/", "_")}.json"
      File.write(dir.join(name), JSON.pretty_generate(model: @model, label: @label, results: results.map(&:to_h)))
    end

    def table(results)
      lines = [ "| Task | Correct | Status | Min | Turns | Input tok | Cached | Cost |", "|---|---|---|---|---|---|---|---|" ]
      results.each do |r|
        lines << "| #{r.key} | #{r.correct ? "✓" : "✗"} | #{r.status} | #{r.minutes} | #{r.turns} | #{r.input_tokens} | #{r.cached_tokens} | $#{r.cost_usd} |"
      end
      correct = results.count(&:correct)
      lines << "| **#{@label || @model}** | **#{correct}/#{results.size}** | | **#{results.sum(&:minutes).round(1)}** | **#{results.sum(&:turns)}** | " \
               "**#{results.sum(&:input_tokens)}** | **#{results.sum(&:cached_tokens)}** | **$#{results.sum(&:cost_usd).round(3)}** |"
      lines.join("\n")
    end
  end
end
