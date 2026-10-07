namespace :agent do
  desc "Run the agent benchmark on a computer: agent:benchmark[computer_id,model,label,only] (only: comma-free keys separated by spaces)"
  task :benchmark, %i[computer_id model label only] => :environment do |_, args|
    computer = AgentComputer.find(args[:computer_id])
    model = args[:model].presence || AgentTask::DEFAULT_MODEL
    AgentBenchmark::Runner.new(computer, model:, label: args[:label].presence, only: args[:only].to_s.split).run
  end
end
