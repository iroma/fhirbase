require 'fhir_pg'
require 'sequel'

Sequel.extension :pg_array_ops, :pg_row_ops
cfg = YAML.load(File.read(File.dirname(__FILE__) + '/connection.yml'))
db = cfg.delete('db')
DB = Sequel.postgres(db, cfg)
DB.extension(:pg_array, :pg_row, :pg_hstore)
