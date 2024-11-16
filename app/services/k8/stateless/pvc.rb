class K8::Stateless::Pvc < K8::Base
  attr_accessor :volume, :project
  delegate :name, to: :volume

  def initialize(volume)
    @volume = volume
    @project = volume.project
  end
end
