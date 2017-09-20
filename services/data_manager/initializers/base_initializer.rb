class BaseInitializer
  def initialize(app:)
    self.app = app
  end

  def run
    raise StandardError.new('`run` has not been implemented for this initializer')
  end

  private

  attr_accessor :app
end
