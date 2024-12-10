module Loggable
  extend ActiveSupport::Concern

  included do
    has_one :log_output, as: :loggable, dependent: :destroy
  end

  def info(line, color: nil)
    color = LogColorsHelper::FRIENDLY_COLORS[color]
    output = "\e[#{color}m#{line}\e[0m"
    Rails.logger.info(line)
    ensure_log_output
    log_output.update(output: log_output.output.to_s + output + "\n")
  end

  def error(line)
    info(line, color: :red)
  end

  def success(line)
    info(line, color: :green)
  end

  private

  def ensure_log_output
    create_log_output if log_output.nil?
  end

  def create_log_output
    self.log_output = LogOutput.create!(loggable: self)
  end
end
