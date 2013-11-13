require 'spec_helper'

describe FhirPg do
  subject { described_class }

  example do
    sql = ''
    sql<< "drop schema if exists fhir cascade;\n"
    sql<< "create schema fhir;\n"
    sql<<  subject.schema
    DB.execute(sql)
  end
end
