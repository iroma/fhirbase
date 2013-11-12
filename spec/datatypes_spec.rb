require 'spec_helper'

describe FhirPg::Datatypes do
  subject { described_class }

  let(:xml) {
    FhirPg::Xml.load('test/fhir-base.xsd')
  }

  it "#nodes" do
    nodes = subject.nodes(xml)
    nodes.size.should > 10
  end

  it "#indexed_nodes" do
    nodes = subject.index_nodes_by_name(xml)
    nodes.should be_a(Hash)
    nodes[:address].should_not be_nil
  end

  it "#collect_enums" do
    idx = subject.index_nodes_by_name(xml)
    enums = subject.collect_enums(idx)
    nu = enums[:name_use]
    nu[:kind] == :enum
    nu[:name] == :name_use
    nu[:options].should include('usual')
  end

  it "#collect_primitive" do
    idx = subject.index_nodes_by_name(xml)
    items = subject.collect_primitives(idx)
    str = items[:string]
    str[:name] == :string
    str[:kind] == :primitive
    str[:type] == 'string'
  end

  it "#collect_types" do
    idx = subject.index_nodes_by_name(xml)
    items = subject.collect_types(idx,
                                  subject.collect_enums(idx),
                                  subject.collect_primitives(idx))
    cc = items[:codeable_concept]
    cc[:name].should == :codeable_concept
    cc[:kind].should == :complex_type
    cc[:type].should == :codeable_concept
    attrs = cc[:attrs]
    cd =  attrs[:coding]
    cd[:name].should == :coding
    cd[:kind].should == :complex_type
    cd[:type].should == :coding
    txt = cc[:attrs][:text]
    txt[:kind].should == :primitive
    txt[:type].should == :string
  end

  it "#mk_db" do
    db = subject.mk_db(xml)
    db[:codeable_concept].should_not be_nil
    db[:string].should_not be_nil
    db[:address].should_not be_nil
  end

  it "mount" do
    db = subject.mk_db(xml)
    tree = subject.mount(db, 'user.name.gender', :codeable_concept)
    tree[:path].should == 'user.name.gender'
    tree[:type].should == :codeable_concept
    tree[:name].should == :gender
    tree[:attrs][:coding][:path].should == 'user.name.gender.coding'
    tree[:attrs][:coding][:collection].should be_true
  end
end
