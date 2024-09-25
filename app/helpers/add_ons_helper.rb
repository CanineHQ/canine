module AddOnsHelper
  def add_on_layout(add_on, &block)
    render layout: 'add_ons/layout', locals: { add_on: }, &block
  end
end
