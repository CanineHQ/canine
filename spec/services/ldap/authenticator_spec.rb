# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LDAP::Authenticator do
  let(:ldap_config) { build(:ldap_configuration) }
  let(:logger) { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:authenticator) { described_class.new(ldap_config, logger: logger) }

  let(:reader_ldap) { instance_double(Net::LDAP) }
  let(:user_ldap) { instance_double(Net::LDAP) }
  let(:operation_result) { double('OperationResult', message: 'Success') }

  let(:user_entry) do
    entry = Net::LDAP::Entry.new("uid=john,#{ldap_config.base_dn}")
    entry[:uid] = [ 'john' ]
    entry[:mail] = [ 'john@example.com' ]
    entry[:cn] = [ 'John Doe' ]
    entry
  end

  before do
    allow(Net::LDAP).to receive(:new).and_return(reader_ldap, user_ldap)
    allow(reader_ldap).to receive(:get_operation_result).and_return(operation_result)
    allow(user_ldap).to receive(:get_operation_result).and_return(operation_result)
    allow(user_ldap).to receive(:auth)
  end

  describe '#call' do
    context 'when reader bind fails' do
      before do
        allow(reader_ldap).to receive(:bind).and_return(false)
        allow(operation_result).to receive(:message).and_return('Invalid credentials')
      end

      it 'returns failure result' do
        result = authenticator.call(username: 'john', password: 'secret', fetch_groups: false)

        expect(result.success?).to be false
        expect(result.error_message).to include('LDAP reader bind failed')
      end
    end

    context 'when user is not found' do
      before do
        allow(reader_ldap).to receive(:bind).and_return(true)
        allow(reader_ldap).to receive(:search).and_yield(nil)
      end

      it 'returns failure result' do
        result = authenticator.call(username: 'nonexistent', password: 'secret', fetch_groups: false)

        expect(result.success?).to be false
        expect(result.error_message).to include('no user entry found')
      end
    end

    context 'when user bind fails (wrong password)' do
      before do
        allow(reader_ldap).to receive(:bind).and_return(true)
        allow(reader_ldap).to receive(:search).and_yield(user_entry)
        allow(user_ldap).to receive(:bind).and_return(false)
        allow(operation_result).to receive(:message).and_return('Invalid credentials')
      end

      it 'returns failure result' do
        result = authenticator.call(username: 'john', password: 'wrong', fetch_groups: false)

        expect(result.success?).to be false
        expect(result.error_message).to include('LDAP user bind failed')
      end
    end

    context 'when authentication succeeds' do
      before do
        allow(reader_ldap).to receive(:bind).and_return(true)
        allow(reader_ldap).to receive(:search).and_yield(user_entry)
        allow(user_ldap).to receive(:bind).and_return(true)
      end

      it 'returns success result with user info' do
        result = authenticator.call(username: 'john', password: 'secret', fetch_groups: false)

        expect(result.success?).to be true
        expect(result.email).to eq('john@example.com')
        expect(result.name).to eq('John Doe')
        expect(result.user_dn).to eq("uid=john,#{ldap_config.base_dn}")
        expect(result.groups).to eq([])
      end

      context 'with fetch_groups: true' do
        let(:group_ldap) { instance_double(Net::LDAP) }
        let(:group_entry) do
          entry = Net::LDAP::Entry.new("cn=developers,#{ldap_config.base_dn}")
          entry[:cn] = [ 'developers' ]
          entry
        end

        before do
          # First Net::LDAP.new returns reader_ldap (for user search)
          # Second returns user_ldap (for auth bind)
          # Third returns group_ldap (for group search)
          allow(Net::LDAP).to receive(:new).and_return(reader_ldap, user_ldap, group_ldap)
          allow(group_ldap).to receive(:bind).and_return(true)
          allow(group_ldap).to receive(:search).and_yield(group_entry)
        end

        it 'fetches group membership' do
          result = authenticator.call(username: 'john', password: 'secret', fetch_groups: true)

          expect(result.success?).to be true
          expect(result.groups).to include({ name: 'developers' })
        end
      end
    end

    context 'when email attribute is missing' do
      let(:user_entry_no_email) do
        entry = Net::LDAP::Entry.new("uid=john,#{ldap_config.base_dn}")
        entry[:uid] = [ 'john' ]
        entry[:cn] = [ 'John Doe' ]
        entry
      end

      before do
        allow(reader_ldap).to receive(:bind).and_return(true)
        allow(reader_ldap).to receive(:search).and_yield(user_entry_no_email)
        allow(user_ldap).to receive(:bind).and_return(true)
      end

      it 'constructs email from username and host' do
        result = authenticator.call(username: 'john', password: 'secret', fetch_groups: false)

        expect(result.success?).to be true
        expect(result.email).to eq("john@#{ldap_config.host}")
      end

      context 'when username already contains @' do
        it 'uses username as email' do
          result = authenticator.call(username: 'john@company.com', password: 'secret', fetch_groups: false)

          expect(result.email).to eq('john@company.com')
        end
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(reader_ldap).to receive(:bind).and_raise(StandardError.new('Connection refused'))
      end

      it 'returns failure result with error message' do
        result = authenticator.call(username: 'john', password: 'secret', fetch_groups: false)

        expect(result.success?).to be false
        expect(result.error_message).to eq('Connection refused')
      end
    end
  end

  describe 'encryption settings' do
    context 'with plain encryption' do
      let(:ldap_config) { build(:ldap_configuration, encryption: 'plain') }

      it 'creates connection without encryption' do
        allow(reader_ldap).to receive(:bind).and_return(false)

        authenticator.call(username: 'john', password: 'secret', fetch_groups: false)

        expect(Net::LDAP).to have_received(:new).with(
          hash_including(host: ldap_config.host, port: ldap_config.port)
        )
      end
    end

    context 'with start_tls encryption' do
      let(:ldap_config) { build(:ldap_configuration, encryption: 'start_tls') }

      it 'creates connection with start_tls' do
        allow(reader_ldap).to receive(:bind).and_return(false)

        authenticator.call(username: 'john', password: 'secret', fetch_groups: false)

        expect(Net::LDAP).to have_received(:new).with(
          hash_including(encryption: { method: :start_tls })
        )
      end
    end

    context 'with simple_tls encryption' do
      let(:ldap_config) { build(:ldap_configuration, encryption: 'simple_tls') }

      it 'creates connection with simple_tls' do
        allow(reader_ldap).to receive(:bind).and_return(false)

        authenticator.call(username: 'john', password: 'secret', fetch_groups: false)

        expect(Net::LDAP).to have_received(:new).with(
          hash_including(encryption: { method: :simple_tls })
        )
      end
    end
  end

  describe 'custom attribute mapping' do
    let(:ldap_config) do
      build(:ldap_configuration,
        uid_attribute: 'sAMAccountName',
        email_attribute: 'userPrincipalName',
        name_attribute: 'displayName'
      )
    end

    let(:ad_user_entry) do
      entry = Net::LDAP::Entry.new("cn=John Doe,#{ldap_config.base_dn}")
      entry[:sAMAccountName] = [ 'jdoe' ]
      entry[:userPrincipalName] = [ 'jdoe@corp.example.com' ]
      entry[:displayName] = [ 'John Q. Doe' ]
      entry
    end

    before do
      allow(reader_ldap).to receive(:bind).and_return(true)
      allow(reader_ldap).to receive(:search).and_yield(ad_user_entry)
      allow(user_ldap).to receive(:bind).and_return(true)
    end

    it 'uses custom attribute mappings' do
      result = authenticator.call(username: 'jdoe', password: 'secret', fetch_groups: false)

      expect(result.success?).to be true
      expect(result.email).to eq('jdoe@corp.example.com')
      expect(result.name).to eq('John Q. Doe')
    end
  end
end
