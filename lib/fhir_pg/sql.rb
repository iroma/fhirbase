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
        when :view
          view_to_sql(item, schema)
        else
          raise "Not suported case #{item[:sql]}"
        end
      end.join("\n")
    end

    private

    def index_to_sql(item, schema)
      table = item[:table]
      column = item[:name]
      index_name = "#{table}_#{column}_idx".split('_').map{|s| s[0..2]}.join('_')
      "CREATE INDEX #{index_name} ON \"#{schema}\".#{table} (#{column});"
    end

    def enum_to_sql(item, schema)
      "CREATE TYPE \"#{schema}\".#{item[:name]} AS ENUM (#{item[:options].map{|o| "'#{o}'"}.join(",")});"
    end

    def columns_to_sql(item, schema)
      item[:columns].map do |col|
        column_to_sql(col, schema)
      end.join(",\n")
    end

    def view_to_sql(item, schema)
      view_name = item[:name]
      "CREATE VIEW \"#{schema}\".view_#{view_name} AS #{item[:query]};"
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
        # 'primary key' created by default
      end
    end

    def table_to_sql(item, schema)
      parent_table = item[:inherits]
      inherits = if parent_table
                   "INHERITS (\"#{schema}\".#{parent_table})"
                 end
      "CREATE TABLE \"#{schema}\".#{item[:name]} (\n#{columns_to_sql(item, schema)},\n PRIMARY KEY(id)) #{inherits};"
    end

    extend self
  end
end
