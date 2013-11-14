require "fhir_pg/version"
require "active_support/core_ext"

module FhirPg
  autoload :Datatypes, 'fhir_pg/datatypes'
  autoload :Xml, 'fhir_pg/xml'
  autoload :Resources, 'fhir_pg/resources'
  autoload :Schema, 'fhir_pg/schema'
  autoload :Meta, 'fhir_pg/meta'
  autoload :Insert, 'fhir_pg/insert'
  autoload :Select, 'fhir_pg/select'
  autoload :SQL, 'fhir_pg/sql'

  def types_db
    @types_db ||= Datatypes.mk_db(Xml.load('test/fhir-base.xsd'))
  end

  def meta
    @meta ||= Resources.mk_db(Xml.load('test/pt.xml'), types_db)
  end

  def schema
    Schema.generate_sql(meta, types_db, 'fhir')
  end

  extend self
end
