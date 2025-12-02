# app/services/ldap/authenticator.rb
require 'net/ldap'

module LDAP
  class Authenticator
    Result = Struct.new(
      :success?,
      :email,
      :name,
      :user_dn,
      :entry,
      :groups,
      :error_message,
      keyword_init: true
    )

    def initialize(ldap_configuration, logger: Rails.logger)
      @config = ldap_configuration
      @logger = logger
    end

    # Public API
    # ----------
    # call(username:, password:) -> Result
    #
    def call(username:, password:)
      # 1) Bind as reader (service account or anonymous)
      reader_ldap = build_reader_connection

      unless reader_ldap.bind
        msg = "LDAP reader bind failed: #{reader_ldap.get_operation_result.message}"
        @logger.warn msg
        return Result.new(success?: false, error_message: msg)
      end

      # 2) Search for the user entry using uid_attribute + filter
      entry = search_user_entry(reader_ldap, username)

      if entry.nil?
        msg = "LDAP search: no user entry found for username=#{username.inspect}"
        @logger.info msg
        return Result.new(success?: false, error_message: msg)
      end

      user_dn = entry.dn

      # 3) Bind as the user to verify the password
      auth_ldap = build_user_auth_connection(user_dn, password)

      unless auth_ldap.bind
        msg = "LDAP user bind failed for DN=#{user_dn}: #{auth_ldap.get_operation_result.message}"
        @logger.info msg
        return Result.new(success?: false, error_message: msg)
      end

      # 4) Successful LDAP auth → map attributes, fetch groups
      email  = resolve_email(entry, username)
      name   = resolve_name(entry, username)
      groups = fetch_group_membership(entry)

      Result.new(
        success?: true,
        email: email,
        name: name,
        user_dn: user_dn,
        entry: entry,
        groups: groups,
        error_message: nil
      )
    rescue => e
      @logger.error "LDAP auth: unexpected error - #{e.class}: #{e.message}"
      Result.new(success?: false, error_message: e.message)
    end

    private

    attr_reader :config, :logger

    # ---------------- CONNECTION HELPERS ----------------

    def build_reader_connection
      # If we have bind_dn/bind_password, use them.
      # Otherwise, only allow anonymous if allow_anonymous_reads is true.
      options = {
        host: config.host,
        port: config.port
      }

      encryption = net_ldap_encryption
      options[:encryption] = encryption if encryption

      if config.bind_dn.present? && config.bind_password.present?
        options[:auth] = {
          method: :simple,
          username: config.bind_dn,
          password: config.bind_password
        }
      elsif !config.allow_anonymous_reads?
        # No way to bind safely
        # Let caller see failure via bind result
        logger.info "LDAP: no reader credentials and anonymous reads disabled"
      end

      Net::LDAP.new(options)
    end

    def build_user_auth_connection(user_dn, password)
      options = {
        host: config.host,
        port: config.port
      }

      encryption = net_ldap_encryption
      options[:encryption] = encryption if encryption

      ldap = Net::LDAP.new(options)
      ldap.auth(user_dn, password)
      ldap
    end

    # Map your `encryption` enum to Net::LDAP’s expectations
    #
    # Adjust the case branches here to match your actual enum:
    #   enum encryption: { plain: 0, start_tls: 1, simple_tls: 2 }
    #
    def net_ldap_encryption
      case config.encryption.to_s
      when 'plain', 'none'
        nil
      when 'start_tls'
        { method: :start_tls }
      when 'simple_tls', 'ssl'
        { method: :simple_tls }
      else
        nil
      end
    end

    # ---------------- SEARCH ----------------

    def search_user_entry(ldap, username)
      uid_attr = config.uid_attribute.presence || 'uid'

      user_filter = Net::LDAP::Filter.eq(uid_attr, username)

      # config.filter is an LDAP filter string, e.g. "(objectClass=person)"
      base_filter =
        if config.filter.present?
          Net::LDAP::Filter.construct(config.filter)
        else
          Net::LDAP::Filter.eq('objectClass', '*') # match anything if no filter given
        end

      filter = base_filter & user_filter

      entry = nil
      ldap.search(base: config.base_dn, filter: filter, size: 2) do |e|
        entry = e
        break
      end

      entry
    end

    # ---------------- ATTRIBUTE MAPPING ----------------

    def resolve_email(entry, username)
      attr = config.email_attribute.presence || 'mail'

      if entry[attr].present?
        entry[attr].first
      else
        # Fallback to username or constructed email
        construct_email(username)
      end
    end

    def resolve_name(entry, username)
      attr = config.name_attribute.presence || 'cn'

      if entry[attr].present?
        entry[attr].first
      elsif entry[:cn].present?
        entry[:cn].first
      else
        username
      end
    end

    def construct_email(username)
      return username if username.include?('@')

      domain = config.try(:mail_domain) || config.host
      "#{username}@#{domain}"
    end

    # ---------------- GROUP MEMBERSHIP ----------------

    def fetch_group_membership(user_entry)
      reader_ldap = build_reader_connection
    
      unless reader_ldap.bind
        if config.allow_anonymous_reads?
          logger.warn "LDAP group lookup: anonymous/reader bind failed: #{reader_ldap.get_operation_result.message}"
        else
          logger.info "LDAP group lookup skipped: cannot bind and anonymous reads disabled"
        end
        return []
      end
    
      groups = []
    
      # From the entry
      dn_from_entry = user_entry.dn
    
      uid_attr = config.uid_attribute.presence || 'uid'
      uid_val  = Array(user_entry[uid_attr]).first
    
      # This is the DN your groups seem to be using:
      #   uid=czhu,dc=example,dc=org
      dn_from_uid = if uid_val.present?
        "#{uid_attr}=#{uid_val},#{config.base_dn}"
      end
    
      member_filters = []
    
      # Try DN from entry (cn=... case)
      member_filters << Net::LDAP::Filter.eq('member', dn_from_entry) if dn_from_entry.present?
    
      # Try DN built from uid (uid=... case – this is the one that works for you)
      member_filters << Net::LDAP::Filter.eq('member', dn_from_uid) if dn_from_uid.present?
    
      # Try memberUid=uid (posixGroup style)
      member_filters << Net::LDAP::Filter.eq('memberUid', uid_val) if uid_val.present?
    
      # If for some reason we have no filters, bail out
      return [] if member_filters.empty?
    
      member_filter = member_filters.reduce do |memo, f|
        memo | f
      end
    
      group_filter  = Net::LDAP::Filter.eq('objectClass', 'groupOfNames') |
                      Net::LDAP::Filter.eq('objectClass', 'groupOfUniqueNames') |
                      Net::LDAP::Filter.eq('objectClass', 'posixGroup')
    
      combined_filter = group_filter & member_filter
    
      reader_ldap.search(base: config.base_dn, filter: combined_filter) do |entry|
        groups << { name: entry.cn.first }
      end
    
      logger.info "Found #{groups.size} LDAP groups for user #{dn_from_entry}"
      groups
    rescue => e
      logger.error "LDAP group lookup error for #{dn_from_entry}: #{e.class}: #{e.message}"
      []
    end

  end
end
