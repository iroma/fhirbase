require 'fhir_pg'
require 'sequel'

DB = Sequel.postgres('test', user: 'nicola')
