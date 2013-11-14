module FhirPg
  module Select

    def select_sql(meta_db, resource_name, schema = 'fhir')
      meta = meta_db[resource_name.to_sym]
      raise "Could not find meta for [#{resource_name}]" unless meta.present?
      deep = 0

      table_index = 1
      aliaz = "t1"
      cols = select_columns(aliaz, meta, table_index, nil, deep)

      <<-SQL
select t1.id, row_to_json(#{aliaz}, true) as json from
(
  select id, #{ident(cols, deep + 1)}
  from #{table_name(meta)} #{aliaz}
) #{aliaz}
SQL
    end

    private

    def build_sql(meta, table_index, parent_table = nil, deep = 0)
      aliaz = "t#{table_index}"
      path = meta[:path]
      conditions = [
        root_condition(aliaz, path),
        parent_condition(aliaz, path)
      ].compact.join(' AND ')

      cols = select_columns(aliaz, meta, table_index, parent_table, deep)
      raise "Table without columns #{meta.inspect}" if cols.empty?

      <<-SQL
select
  array_to_json(
    array_agg(row_to_json(#{aliaz}, true)), true) from
    (
      select #{ident(cols, deep + 1)}
      from #{table_name(meta)} #{aliaz}
      #{conditions.present? ? "WHERE #{conditions}" : ''}
    ) #{aliaz}
    SQL
    end

    def select_columns(aliaz, meta, table_index, parent_table, deep)
      [
        select_complex_columns(meta, table_index, parent_table, deep).strip.presence,
        select_simple_columns(aliaz, meta).strip.presence,
        select_ref_columns(aliaz, meta).presence
      ].compact.join(', ')
    end

    def select_simple_columns(aliaz, meta)
      meta[:attrs].values.map do |m|
        next unless column?(m)
        "#{aliaz}.#{m[:name]}"
      end.compact.join(',')
    end

    #FIXME: move to helpers
    def is_ref?(meta)
      meta[:kind] == :ref
    end

    def select_ref_columns(aliaz, meta)
      meta[:attrs].values.map do |m|
        next unless is_ref?(m)
        name = "#{aliaz}.#{m[:name]}"
        "hstore_to_json(hstore(ARRAY['reference', #{name}_reference ,'display',#{name}_display])) as #{m[:name]}"
      end.compact.join(',')
    end

    def select_complex_columns(meta, table_index, parent_table, deep)
      meta[:attrs].values.map do |m|
        next unless table?(m)
        "( #{build_sql(m, table_index + 1, deep + 1)} ) as #{m[:name]}"
      end.compact.join(",\n")
    end

    def agg_root_table_name(path)
      path.split('.').first.underscore
    end

    def root_table?(path)
      path.split('.').size == 1
    end

    def root_condition(aliaz, path)
      return if root_table?(path)
      root_name = agg_root_table_name(path)
      "#{aliaz}.#{root_name}_id = t1.id"
    end

    def deep_table?(path)
      path.split('.').size > 3
    end

    def parent_condition(aliaz, path)
      return unless deep_table?(path)
      parent_name = path.split('.')[0..-2].join('_').underscore
      parent_table = prev(aliaz)
      "#{aliaz}.#{parent_name.singularize}_id = #{parent_table}.id"
    end


    def prev(aliaz)
      't' + (aliaz.gsub('t','').to_i - 1).to_s
    end

    def column?(m)
      m.present? && [:primitive, :enum].include?(m[:kind])
    end

    def table?(m)
      m.present? && [:resource, :complex_type].include?(m[:kind])
    end

    def table_name(meta)
      'fhir.' + meta[:path].gsub('.','_').underscore.pluralize
    end

    def ident(str, deep)
      str.split("\n").map{|l| "#{' '*4*deep}#{l}"}.join("\n")
    end
    extend self
  end
end
