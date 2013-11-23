module FhirPg
  module Schema
    #requires

    def sql
      SQL
    end

    def select
      Select
    end

    #public

    def generate_sql(meta, types_db, schema)
      sql.to_sql(generate(meta, types_db), schema)
    end

    def generate(meta, types_db)
      base_structures = to_base(meta)
      enums = to_enums(types_db)
      tables  = to_tables(meta)
      indexes = to_indexes(tables)
      views = to_views(meta)
      base_structures + enums + tables + indexes + views
    end

    def to_base(meta)
      [
        {sql: :enum, name: 'resource_type', options: meta.keys.map(&:to_s)},
        {
          sql: :table,
          name: 'resources',
          columns: [
            { sql: :column, name: 'resource_type', type: '.resource_type'},
            { sql: :pk, name: 'id', type: 'uuid'},
            { sql: :column, name: 'inline_id', type: 'varchar'},
            { sql: :column, name: 'container_id', type: 'uuid'}
          ]
        }
      ]
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

    def to_views(meta_db)
      meta_db.map do |resource_name, meta|
        {
          sql: :view,
          name: resource_name,
          query: select.select_sql(meta_db, resource_name)
        }
      end
    end

    private

    def to_table(meta)
      return unless [:resource, :complex_type, :extension].include?(meta[:kind])
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
        columns: [primary_key(meta), aggregate_key(path), parent_key(path)].compact + to_columns(meta),
        inherits: meta[:kind] == :resource && 'resources'
      }
    end

    def primary_key(meta)
      { sql: :pk, name: 'id', type: 'uuid'} unless meta[:kind] == :resource
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
    def is_ref?(meta)
      [:ref].include?(meta[:kind])
    end

    def to_columns(meta)
      meta[:attrs].map do |key, attr|
        if is_column?(attr)
          mk_column(attr)
        elsif is_ref?(attr)
          mk_ref_columns(attr)
        end
      end.flatten.compact
    end

    def mk_ref_columns(attr)
      name = attr[:name]
      [
        {sql: :col, name: "#{name}_id", type: 'uuid'},
        {sql: :col, name: "#{name}_type", type: '.resource_type'},
        {sql: :col, name: "#{name}_display", type: 'varchar'},
        {sql: :col, name: "#{name}_reference", type: 'varchar'},
        {sql: :col, name: "#{name}_inlined", type: 'boolean'}
      ]
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
          "instant" => 'timestamp',
          "boolean" => 'boolean',
          "base64_binary" => 'bytea',
          "integer" => 'integer',
          "decimal" => 'decimal',
          "sampled_data_data_type" => 'text',
          "date" => 'date',
          "id" => 'varchar',
          "oid" => 'varchar',
        }[type.to_s] || raise("Unknown type #{type}")

        else
          raise 'Ups'
        end
    end

    extend self
  end
end
