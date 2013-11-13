module FhirPg
  module SQL
    def to_sql(arr, schema)
      arr.map do |item|
        case item[:sql]
        when :enum
          enum_to_sql(item, schema)
        when :table
          table_to_sql(item, schema)
        when :index
          index_to_sql(item, schema)
        else
          raise "Not suported case #{item[:sql]}"
        end
      end.join("\n")
    end

    private

    def index_to_sql(item, schema)
      table = item[:table]
      column = item[:name]
      "CREATE INDEX #{table}_#{column}_idx ON \"#{schema}\".#{table} (#{column});"
    end

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

    def generate_sql(meta, types_db, schema)
      SQL.to_sql(generate(meta, types_db), schema)
    end

    def generate(meta, types_db)
      enums = to_enums(types_db)
      tables  = to_tables(meta)
      indexes = to_indexes(tables)
      enums + tables + indexes
    end

    def to_tables(meta)
      meta.map do |key, str|
        to_table(str)
      end.compact.flatten
    end

    def to_indexes(tables)
      tables.map do |t|
        t[:columns].select{|c| c[:sql] == :fk}.map{|c| {sql: :index, table: t[:name], name: c[:name]}}
      end.flatten
    end

    def to_enums(types_db)
      types_db.values.map do |tp|
        next unless tp[:kind] == :enum
        raise "Enum must have options #{tp.inspect}" if tp[:options].empty?
        {sql: :enum, name: type_name(tp[:name]), options: tp[:options] }
      end.compact
    end

    private

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
