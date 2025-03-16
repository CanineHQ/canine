class Async::BaseViewModel
  attr_accessor :current_user, :params

  def initialize(current_user, params)
    @current_user = current_user
    @params = params
    validate!
  end

  def name
    self.class.name.sub(/^Async::/, '').sub(/ViewModel$/, '')
  end

  def self.expects(*args)
    @expected_params ||= []
    @expected_params.concat(args)
  end

  def self.expected_params
    @expected_params || []
  end

  def render_error
    "<div class='text-red-500'>Error</div>"
  end

  def validate!
    self.class.expected_params.each do |param|
      unless @params.key?(param)
        raise ArgumentError, "Missing expected parameter: #{param}"
      end
    end
  end

  def render(partial_name, locals: {})
    ApplicationController.renderer.render(partial: partial_name, locals:, context: self)
  end
end
