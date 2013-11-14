require 'spec_helper'

describe FhirPg::Schema do
  subject { described_class }

  let(:meta) { FhirPg.meta }
  let(:types_db) {
    FhirPg::Datatypes.mk_db(
      FhirPg::Xml.load('test/fhir-base.xsd'))
  }

  let(:enums) { subject.to_enums(types_db) }

  it "#to_enums" do
    enums.size.should > 1
    nu = enums.find {|e| e[:name] == 'name_use'}
    nu.should_not be_nil
    nu[:options].should include('usual')
  end

  def find_by_name(coll, name)
    coll.find {|c| c[:name] == name }
  end
  let(:tables) { subject.to_tables(meta) }
  let(:indexes) { subject.to_indexes(tables) }

  it "#to_tables" do
    pt = tables.find {|t| t[:name] == 'patients' }
    pt.should_not be_nil
    %w[birth_date active].each do |col_name|
      col = find_by_name(pt[:columns], col_name)
      col.should_not be_nil
    end
    id = find_by_name(pt[:columns], 'id')
    id.should_not be_nil
    id[:sql].should == :pk
    id[:type].should == 'uuid'
    id[:collection].should_not be_true
  end

  it "#to_tables" do
    nm = find_by_name(tables, 'patient_names')
    pid = find_by_name(nm[:columns], 'patient_id')
    pid.should_not be_nil
    pid[:sql].should == :fk
    pid[:type].should == 'uuid'
    pid[:parent_table].should == 'patients'
  end

  it "#to_tables" do
    cnt_nm = find_by_name(tables, 'patient_contact_names')
    cnt_nm.should_not be_nil

    pid = find_by_name(cnt_nm[:columns], 'patient_id')
    pid.should_not be_nil
    pid[:sql].should == :fk
    pid[:type].should == 'uuid'
    pid[:parent_table].should == 'patients'

    cid = find_by_name(cnt_nm[:columns], 'patient_contact_id')
    cid.should_not be_nil
    cid[:sql].should == :fk
    cid[:type].should == 'uuid'
    cid[:parent_table].should == 'patient_contacts'
  end

  it "regression" do
    lnk = find_by_name(tables, 'patient_links')
    names = lnk[:columns].map{|c| c[:name]}
    names.size.should == names.uniq.size
  end

  example "views" do
    views = subject.to_views(meta)
    views.should_not be_empty
    pt_v = views.find {|v| v[:name] == :patient }
    pt_v.should_not be_nil
  end

  it 'indexes' do
    lnk = find_by_name tables, 'patient_links'
    indexes = subject.to_indexes([lnk])
    indexes.size.should == 1
    index = indexes.first
    index[:sql].should == :index
    index[:table].should == 'patient_links'
    index[:name].should == 'patient_id'
  end

  it "sql" do
    sql = ''
    sql<< "drop schema if exists fhir cascade;\n"
    sql<< "create schema fhir;\n"
    sql<<  subject.generate_sql(meta, types_db, 'fhir')
    DB.execute(sql)
  end
end
