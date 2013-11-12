module FhirPg
  module Datatypes
    # deps
    def meta
      Meta
    end

    def mk_db(xml)
      name_idx = index_nodes_by_name

      {}.tap do |db|
        db.merge(collect_enums(idx))
        db.merge(collect_simple_types(idx))
        db.merge(collect_complex_types(idx))
      end
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
        key = list_key.to_s.gsub(/_list$/,'').to_sym
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
        key = p_key.to_s.gsub(/_primitive$/,'').to_sym
        node =  idx[key]
        p_node = idx[p_key]
        [key, mk_primitive(key, p_node)] if node.present?
      end
    end

    def mk_primitive(kye, p_node)
      {
        name: key,
        kind: :primitive,
        type: type(p_node)
      }
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
      normalize_name(node[:type])
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

    def child_path(parent_path, child)
      "#{parent_path}.#{child}"
    end

    def normalize_name(str)
      str.to_s.underscore
    end

    extend self
  end
end
