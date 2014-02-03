module FhirPg
  module Resources
    #requires
    def dt
      FhirPg::Datatypes
    end

    def meta
      FhirPg::Meta
    end

    #public

    def mk_db(xml, types_db)
      mk_index(xml.xpath('//structure')) do |node|
        key = normalize_name(node.xpath('./type').first[:value])
        [key, mk_resource(key, node, types_db)]
      end
    end

    private

    def add_default_resource_attrs(attrs)
      attrs[:resource_type] = meta.mk_meta(kind: :enum, type: :resource_type, name: :resource_type, path: :resource_type)
    end

    def mk_resource(key, node, types_db)
      el_nodes = node.xpath('./element')
      attrs = expand_complex_types(types_db, collect_attrs(key, el_nodes))
      add_default_resource_attrs(attrs)
      meta.mk_meta(
        name: key,
        kind: :resource,
        path: key.to_s,
        type: key,
        attrs: attrs
      )
    end

    def collect_attrs(parent_path, el_nodes)
      el_nodes.each_with_object({}) do |node, acc|
        next unless direct_parent?(parent_path, node)
        next if technical?(node)
        key = el_name(node)
        types = el_types(node)
        collection = el_collection?(node)
        required = el_collection?(node)

        #polimorphic case
        if types.size > 1
          types.each do |type|
            k = "#{key}_#{type}".to_sym
            pth = "#{parent_path}.#{k}"
              acc[k] = {
              name: k,
              path: pth,
              type: type,
              collection: collection,
              required: required

            }
          end
        else
          pth = "#{parent_path}.#{key}"
          attrs = collect_attrs(pth, el_nodes)
          acc[key] = {
            name: key,
            path: pth,
            kind: el_kind(types.first, attrs),
            type: types.first,
            attrs: attrs,
            collection: collection,
            required: required
          }
        end
      end
    end

    def el_kind(type, attrs)
      return :ref if type =~ /resource\(/
      attrs.present? ? :complex_type : :unknown
    end

    # mutating function
    def expand_complex_types(types_db, attrs)
      return unless attrs.present?
      attrs.each do |key, attr|
        #recur
        expand_complex_types(types_db, attr[:attrs])
        next unless types_db.key?(attr[:type])
        attr.merge!(dt.mount(types_db, attr[:path], attr[:type]))
      end
      attrs
    end

    #TODO: move to utils
    def mk_index(collection)
      collection.each_with_object({}) do |el, acc|
        key, val = yield(el)
        next unless key.present?
        next unless val.present?
        acc[key.to_sym] = val
      end
    end

    private

    def normalize_name(str)
      str.to_s.underscore.to_sym
    end

    def el_path(el)
      pth = el.xpath("./path").first.try(:[], :value)
      pth.gsub('[x]','').underscore if pth
    end

    def el_name(el)
      normalize_name(el_path(el).split('.').last).to_sym
    end

    def el_attr(el, attr)
      el.xpath("./definition/#{attr}").first[:value]
    end

    def el_collection?(el)
      el_attr(el, 'max') == '*'
    end

    def el_required?(el)
      el_attr(el, 'min') == '1'
    end

    def direct_parent?(ppath, el)
      path = el_path(el)
      path.start_with?(ppath.to_s) && (path.split('.') - ppath.to_s.split('.')).size == 1
    end

    def technical?(node)
      el_path(node) =~ /(contained|extension)$/ || ['Extension', 'Narrative'].include?(el_types(node).first)
    end

    def el_types(el)
      el.xpath("./definition/type/code").map do |c|
        normalize_name(c[:value])
      end.compact
    end

    extend self
  end
end
