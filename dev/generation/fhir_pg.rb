require "fhir_pg/version"
require "active_support/core_ext"
require "pg"

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

  def resources_db
    @resources_db ||= Resources.mk_db(Xml.load('test/adt.xml'), types_db)
  end

  def meta
    @meta ||= Extensions.mk_db(Xml.load('test/extension.xml'), resources_db, types_db)
  end

  def schema
    Schema.generate_sql(meta, types_db, 'fhir')
  end

  def generate_schema
    schema = 'fhir'
    medapp_js = PG::Connection.escape_string(File.read(__dir__ + '/../js_build/medapp.js'))
    sql = <<-SQL
      drop schema if exists #{schema} cascade;
      create schema #{schema};
      CREATE EXTENSION IF NOT EXISTS plv8;
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
      CREATE EXTENSION IF NOT EXISTS hstore;
      drop table if exists plv8_modules;
      create table plv8_modules(modname text primary key, load_on_start boolean, code text);

      drop function  public.plv8_init();
      create OR replace function public.plv8_init()
        returns void
        language plv8
        as $$
        this.load_module = function(modname) {
          var rows = plv8.execute("SELECT code from plv8_modules where modname = $1", [modname]);
          for (var r = 0; r < rows.length; r++) {
            eval(rows[r].code)
          }
        };
      $$;
      insert into plv8_modules values ('medapp', true, E'#{medapp_js}');
      create OR replace function public.insert_resource(json json)
        returns void
        language plv8
        as $$
        load_module('medapp');
        sql.insert_resource(json)
      $$;
    SQL
    sql<< Schema.generate_sql(meta, types_db, schema)
    sql
  end

  def reload_schema(db, schema)
    sql = ''
    sql<< "drop schema if exists #{schema} cascade;\n"
    sql<< generate_schema
    db.execute(sql)
  end

  extend self
end
