# == Schema Information
#
# Table name: build_packs
#
#  id                     :bigint           not null, primary key
#  build_order            :integer          not null
#  details                :jsonb
#  name                   :string
#  namespace              :string
#  reference_type         :integer          not null
#  uri                    :text
#  version                :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  build_configuration_id :bigint           not null
#
# Indexes
#
#  index_build_packs_on_build_configuration_id      (build_configuration_id)
#  index_build_packs_on_config_type_namespace_name  (build_configuration_id,reference_type,namespace,name)
#  index_build_packs_on_config_uri                  (build_configuration_id,uri)
#
# Foreign Keys
#
#  fk_rails_...  (build_configuration_id => build_configurations.id)
#
FactoryBot.define do
  factory :build_pack do
    build_configuration
    reference_type { "registry" }
    namespace { "paketo-buildpacks" }
    name { "ruby" }
    version { "0.47.7" }
    details do
      {
        "description" => "A language family buildpack for building Ruby apps",
        "homepage" => "https://github.com/paketo-buildpacks/ruby",
        "licenses" => [ "Apache-2.0" ],
        "stacks" => [ "io.buildpacks.stacks.bionic", "io.buildpacks.stacks.jammy" ]
      }
    end

    trait :git do
      reference_type { "git" }
      namespace { nil }
      name { nil }
      version { nil }
      uri { "https://github.com/DataDog/heroku-buildpack-datadog.git" }
      details { {} }
    end

    trait :url do
      reference_type { "url" }
      namespace { nil }
      name { nil }
      version { nil }
      uri { "https://github.com/heroku/buildpacks-ruby/releases/download/v0.1.0/buildpack.tgz" }
      details { {} }
    end
  end
end
