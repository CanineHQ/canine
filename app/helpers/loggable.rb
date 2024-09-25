module Loggable
  extend ActiveSupport::Concern

  included do
    has_one :log_output, as: :loggable, dependent: :destroy
  end

  def info(line)
    Rails.logger.info(line)
    ensure_log_output
    log_output.update(output: log_output.output.to_s + line + "\n")
  end

  private

  def ensure_log_output
    create_log_output if log_output.nil?
  end

  def create_log_output
    self.log_output = LogOutput.create!(loggable: self)
  end
end
