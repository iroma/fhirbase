require 'uuid'
module FhirPg
  module Insert

    def insert(db, meta, obj)
      obj = normalize_keys(obj)
      resource_name =  resource_name(obj)
      root_id = (obj[:id] ||= gen_uuid)
      contained_resources_idx = ids_for_contained(obj.delete(:contained)) if obj[:contained].present?
      obj = set_ids(obj)
      obj = set_root_ids(resource_name, obj)
      obj = set_parent_ids(resource_name, obj)
      insert_recur(db, resource_meta(meta,resource_name), obj, contained_resources_idx)
      obj[:contained] = insert_contained_resources(db, meta, root_id, contained_resources_idx) if contained_resources_idx.present?
      obj
    end



    def insert_contained_resources(db, meta, root_id, contained_resources_idx)
      contained_resources_idx.values.map do |res_attrs|
        insert(db, meta, res_attrs.merge(container_id: root_id, inline: true))
      end
    end

    def ids_for_contained(contained = [])
      contained.each_with_object(new_map) do |res, acc|
        _id = res[:inline_id] = res[:id]
        res[:id] = gen_uuid
        acc[_id] = res
      end
    end

    def insert_recur(db, meta, obj, contained_resources_idx)
      attributes = collect_attributes(meta, obj, contained_resources_idx)
      datasets(db, meta).insert(attributes)
      insert_complex_types(db, meta, obj, contained_resources_idx)
    end

    private


    def collect_attributes(meta, obj, contained_resources_idx)
      attrs = meta[:attrs].each_with_object(new_map) do |(key,attr), acc|
        next if skip_attribute?(key)
        next unless val = obj[key]
        if column?(attr)
          acc[key] = val.is_a?(Array) ? pg_array(val) : val
        elsif is_ref?(attr)
          fill_reference(acc, val, attr, contained_resources_idx)
        end
      end

      obj.each_with_object(attrs) do |(k, v), acc|
        if k.to_s =~ /id$/
          acc[k] = v
        end
      end
    end

    def insert_complex_types(db, meta, obj, contained_resources_idx)
      meta[:attrs].each_with_object(new_map) do |(key, m), acc|
        next if skip_attribute?(key)
        next unless table?(m)
        next unless val = obj[key]
        (val.is_a?(Array) ? val : [val]).each do |v|
          insert_recur(db, m, v, contained_resources_idx)
        end
      end
    end

    def parent_name(meta)
      pth = meta[:path].split('.')
      pth.join('_').underscore + '_id'
    end

    def is_resource?(meta)
      meta[:kind] == :resource
    end

    def has_parent?(meta)
      meta[:path].split('.').size > 2
    end

    def parent_name(meta)
      pth = meta[:path].split('.')
      pth[0..-2].join('_').underscore + '_id'
    end

    def resource_name(obj)
      obj[:resource_type].underscore.to_sym
    end

    def resource_meta(meta, resource_name)
      raise "Resource metainformation #{resource_name} not found" unless meta[resource_name]
      meta[resource_name]
    end

    def normalize_keys(obj)
      obj.each_with_object(new_map).each do |(attr_name, val), acc|
        acc[attr_name.to_s.underscore.to_sym] = case val
                                                when Hash
                                                  normalize_keys(val)
                                                when Array
                                                  val.map do |i|
                                                    i.is_a?(Hash) ? normalize_keys(i) : i
                                                  end
                                                else
                                                  val
                                                end
      end
    end

    def gen_uuid
      UUID.generate
    end

    def root_name(meta)
      pth = meta[:path].split('.')
      "#{pth.first.underscore}_id"
    end


    def is_ref?(meta)
      meta[:kind] == :ref
    end

    def is_extension?(meta)
      meta[:kind] == :extension
    end

    def is_uuid?(str)
      str =~ /^[0-9a-z]{8}(-[0-9a-z]{4}){2}/
    end

    def is_local_ref?(str)
      str && str[0] == '#'
    end

    def fill_reference(attributes, value, meta, contained_resources_idx)
      name = meta[:name]
      reference = value['reference']
      if is_local_ref?(reference)
        ref_name = reference.gsub('#','')
        attributes["#{name}_inlined"] = true
        type = 'organization'
        contained_res =  contained_resources_idx[ref_name]
        raise "Expected contained resource #{ref_name} \nin #{contained_resources_idx.to_yaml}" unless contained_res
        id = contained_res[:id]
      else
        type, id = reference.split('/',2)
        id = is_uuid?(id) ? id : nil
      end
      attributes["#{name}_id"] = id
      attributes["#{name}_type"] = type.underscore
      attributes["#{name}_display"] = value['display']
      attributes["#{name}_reference"] = reference
    end

    def new_map
      ActiveSupport::HashWithIndifferentAccess.new
    end

    def pg_array(args)
      Sequel.pg_array(args)
    end

    def datasets(db, meta)
      key = 'fhir__' + meta[:path].gsub('.','_').underscore
      (@ds ||= {})[key]||= db[key.to_sym]
    end

    def column?(meta)
      [:primitive, :enum].include?(meta[:kind])
    end

    def table?(meta)
      [:resource, :complex_type, :extension].include?(meta[:kind])
    end

    def skip_attribute?(key)
      ['text'].include?(key)
    end

    def prepare_attrs(name, attrs)
    end

    def each_complex_attr(attrs)
      attrs.each_with_object(new_map) do |(key, val), acc|
        acc[key] = case val
                   when Hash
                     yield(key, val)
                   when Array
                     val.map do |i|
                       i.is_a?(Hash) ? yield(key,val) : i
                     end
                   else
                     val
                   end
      end
    end

    def clone_recursive(attrs)
      attrs.each_with_object(new_map) do |(key, val), acc|
        acc[key] = case val
                   when Hash
                     yield(key, val, acc)
                   when Array
                     val.map do |i|
                       i.is_a?(Hash) ? yield(key, val, acc) : i
                     end
                   else
                     val
                   end
      end
    end

    def set_ids(attrs)
      attrs[:id] ||= gen_uuid
      attrs.each_with_object(new_map) do |(key, val), acc|
        acc[key] = for_hashes(val) do |h|
          set_ids(h)
        end
      end
    end

    def for_hashes(val)
      if val.is_a?(Array)
        val.map { |i| i.is_a?(Hash) ? yield(i) : i }
      elsif val.is_a?(Hash)
        yield(val)
      else
        val
      end
    end

    def set_root_ids(root_name, attrs)
      root = {}
      root["#{root_name}_id".to_sym] = attrs[:id]
      root.freeze
      attrs.each_with_object(new_map) do |(key, val), acc|
        acc[key] = for_hashes(val) do |h|
          set_root_ids_recur(h, root)
        end
      end
    end

    def set_root_ids_recur(attrs, root)
      attrs.merge!(root)
      attrs.each_with_object(new_map) do |(key, val), acc|
        acc[key] = for_hashes(val) do |h|
          set_root_ids_recur(h, root)
        end
      end
    end

    def set_parent_ids(root_name, attrs)
      pth = [[root_name, attrs[:id]]]
      attrs.each_with_object(new_map) do |(key, val), acc|
        acc[key] = for_hashes(val) do |h|
          set_parent_ids_recur(pth.dup.push([key, h[:id]]), h)
        end
      end
    end

    def set_parent_ids_recur(pth, attrs)
      if pth.size > 2
        parent_name = pth[0..-2].map(&:first).join('_') + "_id"
        attrs[parent_name.to_sym] = pth[-2].second
      end
      attrs.each_with_object(new_map) do |(key, val), acc|
        acc[key] = for_hashes(val) do |h|
          set_parent_ids_recur(pth.dup.push([key, h[:id]]), h)
        end
      end
    end

    extend self
  end
end
