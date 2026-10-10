module AgentSessions
  # Watches a browse job (AgentLoop::Browse) without model turns: it polls the computer-use server for the steps
  # browser-use has taken and puts each on the timeline (with its screenshot), then, when the job ends, hands the
  # result back to the model and carries the session on. Cancelling the session, or running out of time, stops the
  # job. Modeled on DelegateWatchJob.
  class BrowseWatchJob < ApplicationJob
    queue_as :agent

    def perform(session, job_id, task, cursor = -1)
      return unless session.waiting_for_tool?

      computer_use = session.computer_use
      data = computer_use.browse_events(job_id, after: cursor, wait: 25)
      parent = session.actions.running.where(tool: "browse").last
      done = nil
      data["events"].each do |event|
        cursor = event["n"]
        # page-extracted content can carry null bytes, which Postgres rejects (the screenshot is ASCII base64, skip it)
        event = scrub(event.except("screenshot")).merge("screenshot" => event["screenshot"])
        case event["kind"]
        when "step" then record_step(session, parent, event)
        when "done", "error" then done = event
        end
      end

      # Out of time or cancelled: stop the job and finalize now with the steps so far. Don't keep polling — a browse
      # job whose teardown hangs would never report running=false, stranding the session until the deadline.
      if done.nil? && should_stop?(session)
        stop_job(computer_use, job_id)
        done = { "finished" => false, "errors" => [ AgentLoop::Policy.limit_reached(session) || "the session was stopped" ] }
      end

      if done.nil? && data["running"]
        self.class.perform_later(session, job_id, task, cursor)
      else
        finished(session, parent, task, done)
      end
    rescue AgentComputers::ComputerUse::Error
      self.class.set(wait: 10.seconds).perform_later(session, job_id, task, cursor) # the computer is briefly unreachable
    end

    private

    def should_stop?(session)
      !session.reload.active? || AgentLoop::Policy.limit_reached(session)
    end

    def stop_job(computer_use, job_id)
      computer_use.browse_stop(job_id)
    rescue AgentComputers::ComputerUse::Error
      nil
    end

    # Null bytes (and invalid UTF-8) crash a Postgres insert; browse content can carry them. Scrub every event's
    # strings before anything is stored or summarized, so one bad step can't strand the whole session.
    def scrub(value)
      case value
      when String then value.delete("\u0000").scrub
      when Array then value.map { |v| scrub(v) }
      when Hash then value.transform_values { |v| scrub(v) }
      else value
      end
    end

    # One browser-use step on the timeline: what it was trying to do, what it did, and the screen it ended on. A step
    # that still can't be stored is logged and skipped, never fatal to the watch loop.
    def record_step(session, parent, event)
      activity = parent&.activity || session.current_activity
      action = session.actions.create!(activity:, tool: "browse_step",
                                        arguments: { "goal" => event["goal"], "step" => event["step"], "url" => event["url"],
                                                    "actions" => Array(event["actions"]) },
                                        status: event["error"].present? ? :failed : :done,
                                        result: { "text" => step_text(event) }, started_at: Time.current,
                                        duration_ms: ((event["seconds"] || 0) * 1000).round)
      attach_screenshot(action, event["screenshot"])
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn("Skipped a browse step for session #{session.id}: #{e.message}")
    end

    def step_text(event)
      [ event["evaluation"].presence && "Before: #{event["evaluation"]}",
        event["actions"].present? && "Did: #{Array(event["actions"]).join("; ")}",
        event["results"].present? && "Result: #{Array(event["results"]).join("; ")}",
        event["error"].presence && "Error: #{event["error"]}" ].select { |x| x }.join("\n").presence || "(step)"
    end

    def finished(session, parent, task, done)
      done ||= { "finished" => false, "result" => nil, "errors" => [ "The browse job ended without a result." ] }
      add_cost(session, done.dig("usage", "cost_usd"))
      summary = browse_summary(task, done)
      parent&.update!(status: done["finished"] && done["success"] != false ? :done : :failed,
                      result: { "text" => summary.truncate(4000) },
                      duration_ms: parent.started_at ? ((Time.current - parent.started_at) * 1000).round : 0)
      position = session.messages.unscope(:order).maximum(:position).to_i + 1
      session.messages.create!(position:, role: "user", content: summary)
      session.running!
      TurnJob.perform_later(session)
    end

    def browse_summary(task, done)
      if done["kind"] == "error" || (done["result"].blank? && !done["finished"])
        reason = Array(done["errors"]).first || done["message"] || "it ended without finishing"
        return "The browse task “#{task}” didn't finish: #{reason}. You can try again, or carry on another way."
      end
      visited = Array(done["visited"]).last(8).join(" → ")
      [ "The browse task finished#{done["success"] == false ? " (reported unsuccessful)" : ""}.",
        done["result"].presence && "Result: #{done["result"]}",
        visited.present? && "Pages visited: #{visited}" ].select { |x| x }.join("\n")
    end

    def add_cost(session, cost)
      session.update!(cost_usd: session.cost_usd + cost.to_f) if cost.to_f.positive?
    end

    def attach_screenshot(action, base64)
      return if base64.blank?

      action.screenshot.attach(io: StringIO.new(Base64.decode64(base64)), filename: "browse-#{action.id}.png", content_type: "image/png")
    rescue StandardError => e
      Rails.logger.info("Couldn't attach browse screenshot: #{e.message}")
    end
  end
end
