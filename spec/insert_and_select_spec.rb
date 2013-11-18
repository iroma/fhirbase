require 'spec_helper'

describe FhirPg::Insert do
  subject { described_class }
  def select; FhirPg::Select ; end
  def meta;  FhirPg.meta; end

  before :each do
    FhirPg.reload_schema(DB, 'fhir')
    subject.insert(DB, meta, load_json('pt1'))
    subject.insert(DB, meta, load_json('pt2'))
  end

  def load_json(name)
    file = File.dirname(__FILE__) + "/fixtures/#{name}.json"
      JSON.parse(File.read(file))
  end

  it "select" do
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

  it "selection from views" do
    id_dataset = DB[:fhir__patient_identifiers]
    .where(value: '12345')
    .select(:patient_id)

    patients_view = DB[:fhir__view_patients]
    pt_json = patients_view.where(id: id_dataset).first
    pt = JSON.parse(pt_json[:json])

    pt['resource_type'].should == 'patient'

    mrn = pt['identifier'].find {|i| i['label'] == 'MRN'}
    mrn['value'].should == '12345'
    mo = pt['managing_organization']
    mo.should_not be_nil
    mo['reference'].should == 'Organization/1'

    pt['name'].first['family']
  end

  it "#set_ids" do
    res = subject.send(:set_ids, {
      a: { b: 'val'},
      c: [{d: 'val'}]
    })
    res[:id].should_not be_nil
    res[:a][:id].should_not be_nil
    res[:c].first[:id].should_not be_nil
  end

  it "#set_root_ids" do
    res = subject.send(:set_root_ids, :pt, {
      id: 1,
      a: { b: 'val'},
      c: [{d: 'val'}, { e: {f: 'val'}}]
    })
    res[:id].should_not be_nil
    res[:a][:pt_id].should_not be_nil
    res[:c].first[:pt_id].should_not be_nil
    res[:c].second[:e][:pt_id].should_not be_nil
  end

  it "#set_parent_ids" do
    res = subject.send(:set_parent_ids, :pt, {
      id: 1,
      a: { id: 2, b: {id: 6, v: 'val'}},
      c: [{id: 3, d: 'val'}, {id: 4, e: {id: 5, f: 'val'}}]
    })
    res[:id].should_not be_nil
    res[:a][:b][:pt_a_id].should_not be_nil
    res[:c].second[:e][:pt_c_id].should_not be_nil
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
