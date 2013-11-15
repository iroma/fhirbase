require 'uuid'
module FhirPg
  class Repository
    attr :db
    attr :schema

    # db - sequel db
    def initialize(db, schema)
      Sequel.extension :pg_array_ops, :pg_row_ops
      db.extension(:pg_array, :pg_row, :pg_hstore)
      @db = db
    end

    def meta
      @meta ||= FhirPg.meta
    end

    def view_datasets(name)
      @view_dataset ||= {}
      @view_dataset[name] ||= db["fhir__view_#{name.pluralize}".to_sym]
    end

    def datasets(name)
      @datasets ||= {}
      @datasets[name] ||= db["fhir__#{name.to_s.pluralize}".to_sym]
    end

    def save(attributes)
      attrs  = attributes.dup
      attrs['id'] ||= UUID.generate
      FhirPg::Insert.insert(db, meta, attrs)
      attrs
    end

    def resources_table
      datasets(:resource)
    end

    def find(resource_id)
      resource = resources_table.where(id: resource_id).first
      raise "Resource with id (#{resource_id}) not found" unless resource.present?
      row = view_datasets(resource[:resource_type]).where(id: resource_id).first
      ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(row[:json]))
    end
  end
end
