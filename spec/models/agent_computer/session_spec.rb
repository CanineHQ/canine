# == Schema Information
#
# Table name: agent_computer_sessions
#
#  id            :bigint           not null, primary key
#  cached_tokens :bigint           default(0), not null
#  cost_usd      :decimal(10, 6)   default(0.0), not null
#  error         :text
#  finished_at   :datetime
#  input_tokens  :integer          default(0), not null
#  model         :string           not null
#  notes         :text
#  notes_through :integer
#  output_tokens :integer          default(0), not null
#  provider      :string
#  started_at    :datetime
#  status        :integer          default("queued"), not null
#  summary       :text
#  trigger       :integer          default("scheduled"), not null
#  turns         :integer          default(0), not null
#  window_from   :datetime
#  window_to     :datetime
#  workspace     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  task_id       :bigint           not null
#
# Indexes
#
#  index_agent_computer_sessions_on_task_id             (task_id)
#  index_agent_computer_sessions_on_task_id_and_status  (task_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => agent_computer_tasks.id)
#
require "rails_helper"

RSpec.describe AgentComputer::Session do
  it "claims a workspace of its own: its task's, or a free one, never the person's or another run's" do
    account_user = create(:account_user)
    computer = AgentComputer.create!(name: "desk", cluster: create(:cluster, account: account_user.account), account_user:, status: :running)
    listing = [
      { "workspace" => 1, "visible" => true, "windows" => [] },                                  # the person's screen
      { "workspace" => 2, "visible" => false, "windows" => [ { "agent" => false } ] },          # their windows
      { "workspace" => 3, "visible" => false, "windows" => [ { "agent" => true } ] },           # a run's leftovers
      { "workspace" => 4, "visible" => false, "windows" => [] },
      { "workspace" => 5, "visible" => false, "windows" => [] },
      { "workspace" => 6, "visible" => false, "windows" => [] }
    ]
    computer_use = instance_double(AgentComputers::ComputerUse, workspaces: { "workspaces" => listing })
    allow_any_instance_of(AgentComputer).to receive(:computer_use).and_return(computer_use)
    allow(computer_use).to receive(:clear_workspace)
    run = -> { computer.tasks.create!(name: "Task", instruction: "Do it", model: "test/model").sessions.create!(trigger: :manual, model: "test/model", status: :running) }
    stub_const("AgentComputer::PARALLEL_RUNS", 9)

    first = run.call
    expect(first.claim_workspace!).to eq(4) # empty ones first
    expect(computer_use).to have_received(:clear_workspace).with(4)
    expect(first.claim_workspace!).to eq(4) # and it keeps it
    expect(AgentLoop::SystemPrompt.build(first)).to include("open on workspace 4")
    expect(run.call.claim_workspace!).to eq(5)
    expect(run.call.claim_workspace!).to eq(6)

    task = computer.tasks.create!(name: "Inbox", instruction: "Check Slack", model: "test/model", pinned_workspace: 4)
    expect(task.sessions.create!(trigger: :manual, model: "test/model", status: :running).claim_workspace!).to be_nil # 4's taken

    expect(run.call.claim_workspace!).to eq(3) # then leftovers, cleared before use

    stub_const("AgentComputer::PARALLEL_RUNS", 3)
    computer.sessions.where(workspace: 3).update_all(status: AgentComputer::Session.statuses[:succeeded])
    expect(run.call.claim_workspace!).to be_nil # 3 is free again, but three runs are going (4, 5, 6): it waits
  end
end
