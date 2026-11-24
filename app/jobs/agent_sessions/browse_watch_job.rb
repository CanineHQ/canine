module AgentSessions
  # Watches a browse job (AgentLoop::Browse) without model turns: it polls the computer-use server for the steps
  # browser-use has taken and puts each on the timeline (with its screenshot), then, when the job ends, hands the
  # result back to the model and carries the session on. Cancelling the session, or running out of time, stops the
  # job. Modeled on DelegateWatchJob.
  class BrowseWatchJob < ApplicationJob
    queue_as :agent

    def perform(session, job_id, task, cursor = -1)
      computer_use = session.computer_use
      return stop_after_session_ended(session, computer_use, job_id) unless session.waiting_for_tool?

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
    rescue AgentComputers::ComputerUse::Error => e
      lost = e.message.start_with?("No browse job") # the server restarted, and the job with it
      if lost || should_stop?(session)
        reason = lost ? "the browser job was lost (the computer-use server restarted)" : "the computer stopped answering"
        finished(session, session.actions.running.where(tool: "browse").last, task, { "kind" => "error", "message" => reason })
      else
        self.class.set(wait: 10.seconds).perform_later(session, job_id, task, cursor) # the computer is briefly unreachable
      end
    end

    private

    # The session ended (cancelled) while the browser was still working: stop it, and close the browse on the timeline
    def stop_after_session_ended(session, computer_use, job_id)
      stop_job(computer_use, job_id)
      session.actions.running.where(tool: "browse").find_each do |action|
        action.update!(status: :failed, result: { "text" => "Stopped: the run ended." })
      end
    end

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

    # One browser-use step on the timeline: what it was trying to do, what it did ("did": "Clicked “Pay invoice”"), and
    # its screenshot, with those marked on it where they happened ("marked": the screen it decided from, or the one after
    # the step; see the computer-use server's marks.py). A step that still can't be stored is logged and skipped, never
    # fatal to the watch loop.
    def record_step(session, parent, event)
      activity = parent&.activity || session.current_activity
      return Rails.logger.warn("Skipped a browse step for session #{session.id}: no activity to put it under") unless activity

      action = activity.actions.create!(tool: "browse_step", parent:,
                                        arguments: { "goal" => event["goal"], "step" => event["step"], "url" => event["url"],
                                                    "actions" => Array(event["actions"]), "did" => Array(event["did"]),
                                                    "marked" => event["marked"] },
                                        status: event["error"].present? ? :failed : :done,
                                        result: { "text" => step_text(event) }, started_at: Time.current,
                                        duration_ms: ((event["seconds"] || 0) * 1000).round)
      attach_screenshot(action, event["screenshot"])
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn("Skipped a browse step for session #{session.id}: #{e.message}")
    end

    def step_text(event)
      [ event["evaluation"].presence && "Before: #{event["evaluation"]}",
        (event["did"].presence || event["actions"]).present? && "Did: #{Array(event["did"].presence || event["actions"]).join("; ")}",
        event["results"].present? && "Result: #{Array(event["results"]).join("; ")}",
        event["error"].presence && "Error: #{event["error"]}" ].select { |x| x }.join("\n").presence || "(step)"
    end

    def finished(session, parent, task, done)
      done ||= { "finished" => false, "result" => nil, "errors" => [ "The browse job ended without a result." ] }
      add_usage(session, done["usage"])
      session.update!(kept_tab: done["kept_tab"]) if done["kept_tab"].present?
      summary = browse_summary(task, done, parent)
      parent&.update!(status: done["needs_person"].present? || (done["finished"] && done["success"] != false) ? :done : :failed,
                      result: { "text" => summary.truncate(4000) },
                      duration_ms: parent.started_at ? ((Time.current - parent.started_at) * 1000).round : 0)
      session.resume_with!(summary)
    end

    def browse_summary(task, done, parent = nil)
      if done["needs_person"].present?
        return "The browse task “#{task}” stopped because it needs the person: #{done["needs_person"]} Its page is still " \
               "open, and the next browse call carries on in it. Ask them with ask_person, then call browse again with their " \
               "answer (e.g. \"Enter the code 123456 on the open page and finish signing in\")."
      end
      if done["kind"] == "error" || (done["result"].blank? && !done["finished"])
        reason = Array(done["errors"]).first || done["message"] || "it ended without finishing"
        return [ "The browse task “#{task}” didn't finish: #{reason}.", last_steps(parent),
                 (AgentLoop::Browse::INTERNAL_PAGE if parent&.steps&.any? { |step| step.arguments["url"].to_s.start_with?("chrome://") }),
                 "Carry on from where it got to: a narrower browse that starts there, or another way." ].compact.join("\n")
      end
      visited = Array(done["visited"]).last(8).join(" → ")
      where = done["workspace"] ? " (on workspace #{done["workspace"]})" : ""
      [ "The browse task finished#{where}#{done["success"] == false ? " (reported unsuccessful)" : ""}.",
        done["result"].presence && "Result: #{done["result"]}",
        visited.present? && "Pages visited: #{visited}" ].select { |x| x }.join("\n")
    end

    # Where a browse that didn't finish got to, from its steps on the timeline: browser-use's own result is empty then,
    # and without this the model knew only the first error, not what had worked or which page it was left on
    def last_steps(parent)
      steps = parent&.steps&.last(LAST_STEPS)
      return if steps.blank?

      lines = steps.map do |step|
        args = step.arguments
        error = step.result&.dig("text").to_s.lines.grep(/\AError: /).first&.delete_prefix("Error: ")&.strip&.truncate(200)
        [ "- #{args["goal"].presence || "(step)"}", args["url"].presence && "on #{args["url"]}", error && "failed: #{error}" ]
          .select(&:present?).join(", ")
      end
      "Its last steps:\n#{lines.join("\n")}"
    end
    LAST_STEPS = 5

    # The browser agent's model calls, on top of the loop's own (AgentLoop::Turn)
    def add_usage(session, usage)
      return if usage.blank?

      session.update!(input_tokens: session.input_tokens + usage["input_tokens"].to_i,
                      output_tokens: session.output_tokens + usage["output_tokens"].to_i,
                      cached_tokens: session.cached_tokens + usage["cached_tokens"].to_i,
                      cost_usd: session.cost_usd + usage["cost_usd"].to_f)
    end

    def attach_screenshot(action, base64)
      return if base64.blank?

      action.screenshot.attach(io: StringIO.new(Base64.decode64(base64)), filename: "browse-#{action.id}.png", content_type: "image/png")
    rescue StandardError => e
      Rails.logger.info("Couldn't attach browse screenshot: #{e.message}")
    end
  end
end
