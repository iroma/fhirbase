module FhirPg
  module Meta
    def mk_meta(attrs)
      attrs
    end

    def mk_attrs_collection
      {}
    end

    def add_attr(attrs_collection, attr)
      attrs_collection[attr[:name].to_sym] = attr
    end
  end
end
