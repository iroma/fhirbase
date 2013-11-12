require 'nokogiri'
module FhirPg
  module Xml
    def load(rel_path)
      path = from_root_path(rel_path)
      raise "No such file #{path}" unless File.exists?(path)
      Nokogiri::XML(open(path).read).tap do |doc|
        doc.remove_namespaces!
      end
    end

    private

    def from_root_path(path)
      File.dirname(__FILE__) + "/../../vendor/#{path}"
    end
    extend self
  end
end
