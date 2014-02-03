require 'rubygems'
require 'bundler/setup'
$LOAD_PATH.unshift(File.expand_path(__dir__ + '/generation'))
require 'fhir_pg'

schema =  FhirPg.generate_schema

open(File.expand_path(__dir__ + '/../fhirbase.sql'),'w') do |f|
  f<< schema
end
