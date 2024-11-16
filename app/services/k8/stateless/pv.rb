class K8::Stateless::Pv < K8::Base
  attr_accessor :volume, :project
  delegate :name, to: :volume

  def initialize(volume)
    @volume = volume
    @project = volume.project
  end
end
