class RandomNameGenerator
  ADJECTIVES = %w[quick lazy happy brave clever quiet mighty kind shiny eager]
  NOUNS = %w[fox bear wolf tiger lion eagle owl deer hare dolphin]

  def self.generate_name(prefix = nil)
    adjective = ADJECTIVES.sample
    noun = NOUNS.sample
    name = "#{adjective}-#{noun}"
    prefix ? "#{prefix}-#{name}" : name
  end
end
