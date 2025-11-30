# == Schema Information
#
# Table name: ldap_configurations
#
#  id                    :bigint           not null, primary key
#  allow_anonymous_reads :boolean          default(FALSE)
#  base_dn               :string           not null
#  bind_dn               :string
#  bind_password         :string
#  email_attribute       :string           default("mail")
#  encryption            :integer          not null
#  filter                :string
#  host                  :string           not null
#  name_attribute        :string           default("cn")
#  port                  :integer          default(389), not null
#  reader_dn             :string
#  reader_password       :string
#  uid_attribute         :string           default("uid"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
require 'rails_helper'

RSpec.describe LDAPConfiguration, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
