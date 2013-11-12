module FhirPg
  module Meta
    REQUIRED_ATTRS = [:kind, :name, :type]
    KINDS = [:complex_type, :resource, :enum, :primitive]
    ALLOWED_KEYS = REQUIRED_ATTRS + [:attrs, :options, :path, :required, :collection]

    def mk_meta(attrs)
      check_required!(attrs)
      check_kind!(attrs)
      check_extra!(attrs)
      attrs
    end

    private

    def check_required!(attrs)
      REQUIRED_ATTRS.each do |key|
        v = attrs.fetch(key)
        raise "#{key} required" unless v
      end
    end

    def check_kind!(attrs)
      kind = attrs[:kind]
      raise "#{kind} should be one of #{KINDS}" unless KINDS.include?(kind)
    end

    def check_extra!(attrs)
      extra_keys = attrs.keys - ALLOWED_KEYS
      raise "Extra keys #{extra_keys}" if extra_keys.present?
    end

    extend self
  end
end
