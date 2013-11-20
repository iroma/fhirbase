module FhirPg
  module Extensions
    def schema(x, s = 'fhir_ex')
      [d_s(s), c_s(s), "\n", c_ts(x, s)].compact.join("\n")
    end

    def insert
    end

    def select
    end

    private

    def c_s(s)
      "CREATE SCHEMA #{s};"
    end

    def d_s(s)
      "DROP SCHEMA IF EXISTS #{s} CASCADE;"
    end

    def c_ts(x, s)
      mk_db(x).map do |m|
        c_t(s, m)
      end.compact.join("\n\n")
    end

    def t_n(m)
      m[:context].map(&:to_s).join("_").pluralize
    end

    def t_r(m)
      m[:context].first.to_s
    end

    def c_t(s, m)
      [c_th(s, t_n(m)), c_tc(s, m)].compact.join("\n")
    end

    def c_tc(s, m)
      [
        "id uuid references fhir.#{t_n(m)}(id)",
        "#{t_r(m)}_id uuid references fhir.#{t_r(m).pluralize}(id)",
        "#{m[:code]} #{c_tt(s, m)}",
        "PRIMARY KEY(id));"
      ].map{|c|"  #{c}"}.join(",\n")
    end

    def c_tt(s, m)
      type = m[:definition][:kind].to_s
      {
        "code" => 'varchar',
        "datetime" => 'timestamp',
        "string" => 'varchar',
        "uri" => 'varchar',
        "date_time" => 'timestamp',
        "instant" => 'timestamp',
        "boolean" => 'boolean',
        "base64_binary" => 'bytea',
        "integer" => 'integer',
        "decimal" => 'decimal',
        "sampled_data_data_type" => 'text',
        "date" => 'date',
        "id" => 'varchar',
        "oid" => 'varchar',
      }[type] || raise("Unknown type #{type}")
    end

    def c_th(s, t)
      "CREATE TABLE \"#{s}\".#{t} ("
    end

    def mk_db(x)
      defn(x).map do |n|
        m_e(n) if r?(n)
      end.compact
    end

    def defn(x)
      x.xpath('.//extensionDefn')
    end

    def m_e(n)
      {
        code: e_c(n),
        context_type: e_cnt(n),
        context: e_cn(n),
        definition: e_d(n)
      }
    end

    def r?(n)
      e_cnt(n) == :resource
    end

    def e_c(n)
      nn(n.xpath('./code').first[:value])
    end

    def e_cnt(n)
      n.xpath('./contextType').first[:value].to_sym
    end

    def e_cn(n)
      pt(n.xpath('./context').first[:value])
    end

    def e_d(n)
      {
        kind: n.xpath('./definition/type/code').first[:value].to_sym
      }
    end

    def nn(s)
      s.to_s.underscore.to_sym
    end

    def pt(s)
      s.split('.').map{|p|nn(p)}
    end

    extend self
  end
end
