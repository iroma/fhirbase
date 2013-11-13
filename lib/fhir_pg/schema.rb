module FhirPg
  module SQL
    def to_sql(arr, schema)
      arr.map do |item|
        case item[:sql]
        when :enum
          enum_to_sql(item, schema)
        when :table
          table_to_sql(item, schema)
        end
      end.join("\n")
    end

    private

    def enum_to_sql(item, schema)
      "CREATE TYPE \"#{schema}\".#{item[:name]} AS ENUM (#{item[:options].map{|o| "'#{o}'"}.join(",")});"
    end

    def columns_to_sql(item, schema)
      item[:columns].map do |col|
        column_to_sql(col, schema)
      end.join(",\n")
    end

    def column_to_sql(col, schema)
      [
        column_name(col),
        column_type(col, schema),
        keys_sql(col, schema)
      ].compact.join(' ')
    end

    def column_name(col)
      "\"#{col[:name]}\""
    end

    def column_type(col, schema)
      arr = col[:array] ? '[]' : ''
      type = col[:type].gsub(/^\./, "#{schema}.")
      "#{type}#{arr}"
    end

    def keys_sql(col, schema)
      case col[:sql]
      when :fk
        "references #{schema}.#{col[:parent_table]}(id)"
      when :pk
        'primary key'
      end
    end

    def table_to_sql(item, schema)
      "CREATE TABLE \"#{schema}\".#{item[:name]} (\n#{columns_to_sql(item, schema)}\n);"
    end

    extend self
  end
  module Schema
    DEFAULT_SCHEMA = 'fhir'
    def generate(meta)
    end

    def to_tables(meta, types_db)
      meta.map do |key, str|
        to_table(str)
      end.compact.flatten
    end

    def to_table(meta)
      return unless [:resource, :complex_type].include?(meta[:kind])
      [mk_table(meta)] + meta[:attrs].map do |_,attr|
        to_table(attr)
      end.compact.flatten
    end

    def mk_table(meta)
      path = meta[:path]
      {
        sql: :table,
        name: table_name(path),
        collection: meta[:collection],
        columns: [primary_key, aggregate_key(path), parent_key(path)].compact + to_columns(meta)
      }
    end

    def primary_key
      { sql: :pk, name: 'id', type: 'uuid'}
    end

    def aggregate_key(path)
      pth = path.split('.')
      return if pth.size == 1
      raise 'imposible!!!!' if pth.size == 0
      agg_root = pth.first.underscore
      name = "#{agg_root.singularize}_id"
      { sql: :fk, name: name, type: 'uuid', parent_table: agg_root.pluralize }
    end

    def parent_key(path)
      pth = path.split('.')
      return if pth.size < 3
      parent_table = pth[0..-2].join('_').underscore.pluralize
      name = "#{parent_table.singularize}_id"
      {sql: :fk, name: name, type: 'uuid', parent_table: parent_table}
    end

    def is_column?(meta)
      [:primitive, :enum].include?(meta[:kind])
    end

    def to_columns(meta)
      meta[:attrs].map do |key, attr|
        next unless is_column?(attr)
        mk_column(attr)
      end.compact
    end

    def mk_column(meta)
      {
        sql: :column,
        name: meta[:name].to_s,
        type: type_to_pg(meta)
      }
    end

    def to_enums(types_db)
      types_db.values.map do |tp|
        next unless tp[:kind] == :enum
        raise "Enum must have options #{tp.inspect}" if tp[:options].empty?
        {sql: :enum, name: type_name(tp[:name]), options: tp[:options] }
      end.compact
    end

    private

    def type_name(key)
      key.to_s.gsub('.','_').underscore
    end

    def table_name(name)
      name.to_s.gsub('.','_').underscore.pluralize
    end

    def type_to_pg(meta)
      type = meta[:type]
      kind = meta[:kind]
      if kind == :enum
        ".#{type}"
      elsif kind == :primitive
        {
          "code" => 'varchar',
          "datetime" => 'timestamp',
          "string" => 'varchar',
          "uri" => 'varchar',
          "date_time" => 'timestamp',
          "boolean" => 'boolean',
          "base64_binary" => 'bytea',
          "integer" => 'integer',
          "decimal" => 'decimal',
          "sampled_data_data_type" => 'text',
        }[type.to_s] || raise("Unknown type #{type}")

        else
          raise 'Ups'
        end
    end

    extend self
  end
end
