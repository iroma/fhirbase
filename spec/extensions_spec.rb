require 'spec_helper'

describe FhirPg::Extensions do
  subject { described_class }

  let(:types_xml) { FhirPg::Xml.load('test/fhir-base.xsd') }

  let(:types_db) { FhirPg::Datatypes.mk_db(types_xml) }

  let(:resources_xml) { FhirPg::Xml.load('test/adt.xml') }

  let(:resources_db) { FhirPg::Resources.mk_db(resources_xml, types_db) }

  let(:xml) { FhirPg::Xml.load('test/extension.xml') }

  let(:db) { subject.mk_db(xml, resources_db, types_db) }

  example do
    context = {a: :b}
    db = {c: {d: :e, f: context}}
    subject.send(:find_context, db, [:c, :f]).should == context
  end

  example do
    db[:patient].tap do |p|
      p.should be_present
      p[:attrs][:extension].tap do |e|
        e.should be_present
        e[:name].should == :extension
        e[:kind].should == :extension
        e[:type].should == :extension
        e[:path].should == 'patient.extension'
        e[:attrs].tap do |a|
          a.should be_present
          a[:participation_agreement].tap do |d|
            d.should be_present
            d[:name].should == :participation_agreement
            d[:kind].should == :primitive
            d[:type].should == :uri
            d[:path].should == 'patient.extension.participation_agreement'
            d[:collection].should be_true
          end
        end
      end
      p[:attrs][:contact][:attrs][:name][:attrs][:extension][:attrs][:kind].tap do |c|
        c.should be_present
        c[:name].should == :kind
        c[:kind].should == :complex_type
        c[:type].should == :coding
        c[:path].should == 'patient.contact.name.extension.kind'
        c[:collection].should be_false
        c[:attrs][:system].should be_present
        c[:attrs][:code].should be_present
      end
    end
  end

  example do
    json = load_json('extension')
    obj = subject.prepare(json)
    obj['extension'].first['participation_agreement'].should == 'Some Agreement'
    obj['contact'].first['name']['extension'].first['kind'].first['code'].should == 'partner'
  end

  example do
    json = load_json('extension')
    obj = subject.prepare(json)
    FhirPg::Insert.insert(DB, db, obj)
    sql = FhirPg::Select.select_sql(db, :patient)
    DB[sql].each do |row|
      puts
      puts 'Patient'
      puts '-'*30
      puts compact(JSON.parse(row[:json])).to_yaml
    end
  end

  example do
    json = load_json('extension')
    obj = subject.prepare(json)
    FhirPg::Insert.insert(DB, db, obj)
  end

  let(:tables) { FhirPg::Schema.to_tables(db) }

  example do
    nm = find_by_name(tables, 'patient_extensions')
    nm.should_not be_nil

    id = find_by_name(nm[:columns], 'id')
    id.should_not be_nil
    id[:sql].should == :pk
    id[:type].should == 'uuid'
    id[:collection].should_not be_true

    pid = find_by_name(nm[:columns], 'patient_id')
    pid.should_not be_nil
    pid[:sql].should == :fk
    pid[:type].should == 'uuid'
    pid[:parent_table].should == 'patients'
  end

  example do
    nm = find_by_name(tables, 'patient_contact_name_extension_kinds')
    nm.should_not be_nil

    id = find_by_name(nm[:columns], 'id')
    id.should_not be_nil
    id[:sql].should == :pk
    id[:type].should == 'uuid'
    id[:collection].should_not be_true

    pid = find_by_name(nm[:columns], 'patient_id')
    pid.should_not be_nil
    pid[:sql].should == :fk
    pid[:type].should == 'uuid'
    pid[:parent_table].should == 'patients'
  end

  example do
    sql = ''
    sql<< "drop schema if exists fhir cascade;\n"
    sql<< "create schema fhir;\n"
    sql<<  FhirPg::Schema.generate_sql(db, types_db, 'fhir')

    wfile('schema.sql', sql)
    DB.execute(sql)
  end

  def load_json(name)
    file = File.dirname(__FILE__) + "/fixtures/#{name}.json"
    JSON.parse(File.read(file))
  end

  def find_by_name(coll, name)
    coll.find {|c| c[:name] == name }
  end

  def wfile(name, content)
    open(File.dirname(__FILE__) + "/#{name}", 'w') {|f| f<< content }
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
