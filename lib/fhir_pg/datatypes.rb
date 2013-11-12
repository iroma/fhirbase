module FhirPg
  module Datatypes
    # deps
    def meta
      Meta
    end

    def mk_db(xml)
      idx = index_nodes_by_name(xml)
      enums = collect_enums(idx)
      primitives = collect_primitives(idx)
      types = collect_types(idx, enums, primitives)
      {}.merge(enums).merge(primitives).merge(types)
    end

    def mount(db, parent_path, key, type)
      tp = db[type]
      path = "#{parent_path}.#{key}"
      tp.dup.merge(
        path: path,
        attrs: mount_recur(path, tp[:attrs])
      )
    end

    def mount_recur(path, attrs)
    end

    def nodes(xml)
      (xml.xpath('//simpleType').to_a + xml.xpath('//complexType').to_a)
    end

    def index_nodes_by_name(xml)
      mk_index(nodes(xml)) do |node|
        key = normalize_name(node[:name])
        [key, node] if key.present?
      end
    end

    def collect_enums(idx)
      list_names = idx.keys.select{|n| n.to_s =~/_list$/}
      mk_index(list_names) do |list_key|
        key = unpostfix(list_key, 'list')
        node =  idx[key]
        list_node = idx[list_key]
        [key, mk_enum(key, list_node)] if node.present?
      end
    end

    def mk_enum(key, node)
      {
        name: key,
        kind: :enum,
        options: node.xpath('.//enumeration').map{|n| n[:value]}.compact.sort
      }
    end

    def collect_primitives(idx)
      names = idx.keys.select{|n| n.to_s =~/_primitive$/}
      mk_index(names) do |p_key|
        key = unpostfix(p_key, 'primitive')
        node =  idx[key]
        p_node = idx[p_key]
        [key, mk_primitive(key, p_node)] if node.present?
      end
    end

    def mk_primitive(key, p_node)
      {
        name: key,
        kind: :primitive,
        type: type(p_node)
      }
    end

    def unpostfix(str, *postfix)
      str = str.to_s
      postfix.each do |pfx|
        str.gsub!(/_#{pfx}$/,'')
      end
      str.to_sym
    end

    def collect_types(idx, enums, primitives)
      tmp_types = mk_index(idx) do |(key, node)|
        key = unpostfix(key, 'primitive', 'list')
        next if enums[key]
        next if primitives[key]
        [key, mk_type(key, node)] if key
      end

      fix_complex_types(tmp_types, enums, primitives)
    end

    # dirty algorighm with temporal lookup
    def fix_complex_types(tmp_types, enums, primitives)
      mk_index(tmp_types) do |(key, tp)|
        [
          key,
          tp.dup.merge(attrs: fix_attrs(tp[:attrs], tmp_types, enums, primitives))
        ]
      end
    end

    def fix_attrs(attrs, tmp_types, enums, primitives)
      mk_index(attrs) do |(key, props)|
        type = props[:type].to_sym
        tp = primitives[type] || enums[type] || tmp_types[type]
        raise "Could not find type #{key}: #{props}" unless tp.present?
        [key, tp.dup.merge(props)]
      end
    end

    def mk_type(key, node)
      {
        name: key,
        kind: :complex_type,
        type: key,
        attrs: initial_attrs(key, node)
      }
    end

    def initial_attrs(key, node)
      mk_index(node.xpath('.//element')) do |child_node|
        child_key = normalize_name(child_node[:name])
        [child_key, {
          name: child_key,
          type: normalize_name(child_node[:type]),
          requied: requied?(child_node),
          collection: collection?(child_node)
        }]
      end
    end

    private

    def mk_index(collection)
      collection.each_with_object({}) do |el, acc|
        key, val = yield(el)
        next unless key.present?
        next unless val.present?
        acc[key.to_sym] = val
      end
    end

    def type(node)
      normalize_name(node[:type]).to_sym
    end

    def requied?(node)
      node[:minOccurs] != '0'
    end

    def collection?(node)
      node[:maxOccurs] == 'unbounded'
    end

    def child_path(parent_path, child)
      "#{parent_path}.#{child}"
    end

    def normalize_name(str)
      str.to_s.underscore.to_sym
    end

    extend self
  end
end
