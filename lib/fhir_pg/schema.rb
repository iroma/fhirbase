module FhirPg
  module Schema
    def generate(meta)
      meta.each do |k, m|
        walk(m)
      end
    end

    def walk(node)
      p node[:path] if node[:kind] == :complex_type
      (node[:attrs] || {}).each do |key, sub_node|
        walk(sub_node)
      end
    end
    extend self
  end
end
