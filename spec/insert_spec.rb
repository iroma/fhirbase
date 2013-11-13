require 'spec_helper'

describe FhirPg::Insert do
  subject { described_class }
  let(:meta) { FhirPg.meta }

  before :all do
    sql = ''
    sql<< "drop schema if exists fhir cascade;\n"
    sql<< "create schema fhir;\n"
    sql<<  FhirPg.schema
    DB.execute(sql)
  end

  def load_json(name)
    file = File.dirname(__FILE__) + "/fixtures/#{name}.json"
      JSON.parse(File.read(file))
  end
  let(:select) { FhirPg::Select }

  example do
    subject.insert(DB, meta, load_json('pt1'))
    subject.insert(DB, meta, load_json('pt2'))

    puts DB[:fhir__patient_contact_names].all.to_yaml

    sql = select.select_sql(meta, :patient)
    puts sql
    DB[sql].each do |row|
      puts
      puts 'Patient'
      puts '-'*30
      puts compact(JSON.parse(row[:json])).to_yaml
    end
  end

  def compact(hash)
    hash.each_with_object({}) do |(k,v), acc|
      if v.is_a?(Hash)
        acc[k] = compact(v)
      elsif v.is_a?(Array) && v.present?
        acc[k] = v.map do |i|
          i.is_a?(Hash) ?  compact(i) : i
        end
      else
        if v.present?
          acc[k] = v
        end
      end
    end
  end
end
