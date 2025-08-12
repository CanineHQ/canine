module Loggable
  extend ActiveSupport::Concern

  included do
    has_many :log_outputs, as: :loggable, dependent: :destroy
  end

  def info(line, color: nil)
    color = LogColorsHelper::FRIENDLY_COLORS[color]
    output = "\e[#{color}m#{line}\e[0m"
    Rails.logger.info(line)
    self.log_outputs.create(output: output)
  end

  def error(line)
    info(line, color: :red)
  end

  def success(line)
    info(line, color: :green)
  end

  def warn(line)
    info(line, color: :orange)
  end

  private
end
