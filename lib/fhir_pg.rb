require "fhir_pg/version"
require "active_support/core_ext"

module FhirPg
  autoload :Datatypes, 'fhir_pg/datatypes'
  autoload :Xml, 'fhir_pg/xml'
  autoload :Resources, 'fhir_pg/resources'
  autoload :Schema, 'fhir_pg/schema'
  autoload :Meta, 'fhir_pg/meta'

  def meta
    @meta ||= begin
                Resources.mk_db(
                  Xml.load('test/pt.xml'),
                  Datatypes.mk_db(
                    Xml.load('test/fhir-base.xsd')))
              end
  end

  def schema
    Schema.generate(meta)
  end

  extend self
end
