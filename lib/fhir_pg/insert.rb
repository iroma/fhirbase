require 'uuid'
module FhirPg
  module Insert

    def fix_keys(obj)
      obj = obj.each_with_object({}).each do |(attr_name, val), acc|
        acc[attr_name.to_s.underscore.to_sym] = val
      end
    end

    def gen_uuid
      UUID.generate
    end

    def insert(db, meta, obj, opts = {})
      obj = fix_keys(obj)
      resource_name =  obj[:resource_type].underscore.to_sym
      raise "Resource metainformation #{resource_name} not found" unless meta[resource_name]
      insert_recur(db, meta[resource_name], obj, opts)
    end

    def is_ref?(meta)
      meta[:kind] == :ref
    end

    def is_uuid?(str)
      str =~ /^[0-9a-z]{8}(-[0-9a-z]{4}){2}/
    end

    def fill_reference(attributes, value, meta)
      name = meta[:name]
      type, id = value['reference'].split('/',2)
      #FIXME: put original reference
      id = is_uuid?(id) ? id : nil
      attributes["#{name}_id"] = id
      attributes["#{name}_type"] = type.underscore
      attributes["#{name}_display"] = value['display']
      attributes["#{name}_reference"] = value['reference']
    end

    def insert_recur(db, meta, obj, opts = {})
      obj = fix_keys(obj)
      uuid = gen_uuid
      attributes = meta[:attrs].each_with_object({}) do |(key,attr), acc|
        next if skip_attribute?(key)
        next unless val = obj[key]
        if column?(attr)
          acc[key] = val.is_a?(Array) ? pg_array(val) : val
        elsif is_ref?(attr)
          fill_reference(acc, val, attr)
        end
      end.merge(id: uuid).merge(opts)

      datasets(db, meta).insert(attributes)

      # recursion

      pth = meta[:path].split('.')
      new_opts = {}
      root_name = "#{pth.first.underscore}_id"
      new_opts[root_name] = opts[root_name] || uuid
      if pth.size > 1
        new_opts[pth.join('_').underscore.singularize + '_id'] = uuid
      end

      meta[:attrs].each_with_object({}) do |(key, m), acc|
        next if skip_attribute?(key)
        next unless table?(m)
        next unless val = obj[key]
        (val.is_a?(Array) ? val : [val]).each do |v|
          insert_recur(db, m, v, new_opts)
        end
      end
    end

    def pg_array(args)
      Sequel.pg_array(args)
    end

    def datasets(db, meta)
      key = 'fhir__' + meta[:path].gsub('.','_').underscore.pluralize
      (@ds ||= {})[key]||= db[key.to_sym]
    end

    def column?(meta)
      [:primitive, :enum].include?(meta[:kind])
    end

    def table?(meta)
      [:resource, :complex_type].include?(meta[:kind])
    end

    def skip_attribute?(key)
      ['resource_type', 'text'].include?(key)
    end

    extend self
  end
end
