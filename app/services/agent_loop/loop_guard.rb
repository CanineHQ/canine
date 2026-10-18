module AgentLoop
  # Notices an agent repeating itself (models get stuck: one reply asked for the same search 2,220 times). The same
  # call over and over earns a nudge, then a stop. Calls are compared without their intent.
  module LoopGuard
    WINDOW = 20         # look at this many recent actions
    NUDGE_AT = [ 5, 8 ] # repeats that earn a nudge...
    STOP_AT = 12        # ...and that end the session

    def self.key(name, args)
      [ name, args.except("intent").sort.to_h ].to_json
    end

    # The largest number of times one call appears in the session's recent actions
    def self.repeats(session)
      recent = session.actions.unscope(:order).order(created_at: :desc).limit(WINDOW)
      recent.map { |action| key(action.tool, action.arguments.to_h) }.tally.values.max.to_i
    end

    # What to tell the model, if anything, and whether to stop
    def self.check(session)
      count = repeats(session)
      return [ :stop, "Stopped: the same call was repeated #{count} times without progress." ] if count >= STOP_AT
      return unless NUDGE_AT.include?(count)

      [ :nudge, "You've made the same call #{count} times in your last #{WINDOW} actions. It isn't getting you anywhere: " \
                "try a different approach (another tool, a search, a URL), or finish with what you have." ]
    end
  end
end
