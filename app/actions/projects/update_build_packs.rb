class Projects::UpdateBuildPacks
  extend LightService::Action

  expects :build_configuration, :params

  executed do |context|
    build_configuration = context.build_configuration
    next context unless build_configuration&.buildpacks?

    build_packs_params = context.params
      .dig(:project, :build_configuration, :build_packs_attributes) || []

    # Create a hash of existing build packs keyed by build_pack.key
    existing_packs = {}
    build_configuration.build_packs.each do |pack|
      existing_packs[pack.key] = pack
    end

    # Track which build packs are in the params and their order
    incoming_keys = []

    ActiveRecord::Base.transaction do
      # Process each incoming build pack
      build_packs_params.each_with_index do |pack_params, build_order|
        permitted = pack_params.permit(:namespace, :name, :version, :reference_type)
        namespace = permitted[:namespace]
        name = permitted[:name]

        key = "#{namespace}/#{name}"
        next if namespace.blank? || name.blank?

        incoming_keys << key unless incoming_keys.include?(key)

        if existing_packs[key]
          # Build pack already exists, update its order
          build_pack = existing_packs[key]
          build_pack.build_order = build_order
        else
          # Build pack doesn't exist, create it and fetch details
          build_pack = build_configuration.build_packs.build(permitted.merge(build_order:))
          Projects::InitializeBuildPacks.fetch_buildpack_details!(build_pack)
        end
        build_pack.save!
      end

      # Delete build packs that are not in the incoming params (only persisted ones)
      packs_to_delete = build_configuration.build_packs.reject do |pack|
        incoming_keys.include?(pack.key)
      end
      packs_to_delete.each(&:destroy!)
    end

    context
  end
end