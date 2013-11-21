require "fhir_pg/version"
require "active_support/core_ext"

module FhirPg
  autoload :Datatypes, 'fhir_pg/datatypes'
  autoload :Extensions, 'fhir_pg/extensions'
  autoload :Xml, 'fhir_pg/xml'
  autoload :Resources, 'fhir_pg/resources'
  autoload :Schema, 'fhir_pg/schema'
  autoload :Meta, 'fhir_pg/meta'
  autoload :Insert, 'fhir_pg/insert'
  autoload :Select, 'fhir_pg/select'
  autoload :SQL, 'fhir_pg/sql'
  autoload :Repository, 'fhir_pg/repository'
  autoload :Relational, 'fhir_pg/relational'

  def types_db
    @types_db ||= Datatypes.mk_db(Xml.load('test/fhir-base.xsd'))
  end

  def meta
    @meta ||= Resources.mk_db(Xml.load('test/adt.xml'), types_db)
  end

  def schema
    Schema.generate_sql(meta, types_db, 'fhir')
  end

  def reload_schema(db, schema)
    sql = ''
    sql<< "drop schema if exists #{schema} cascade;\n"
    sql<< "create schema #{schema};\n"
    sql<<  self.schema
    db.execute(sql)
  end

  extend self
end
