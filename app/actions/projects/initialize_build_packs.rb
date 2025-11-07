# frozen_string_literal: true

module Projects
  class InitializeBuildPacks
    extend LightService::Action

    expects :build_configuration, :params
    promises :build_packs, optional: true

    def self.fetch_buildpack_details!(build_pack)
      result = Buildpacks::Details.execute(
        namespace: build_pack.namespace,
        name: build_pack.name
      )
      build_pack.details = result.result.to_h
      build_pack
    end

    executed do |context|
      build_configuration = context.build_configuration
      next context unless build_configuration&.buildpacks?

      build_packs_params = context.params
        .dig(:project, :build_configuration, :build_packs_attributes) || []
      next context unless build_packs_params

      context.build_packs = build_packs_params.map.with_index do |pack_params, build_order|
        permitted = pack_params.permit(:namespace, :name, :version, :reference_type)
        build_pack = build_configuration.build_packs.build(permitted.merge(build_order:))
        fetch_buildpack_details!(build_pack)
      end
    end
  end
end
