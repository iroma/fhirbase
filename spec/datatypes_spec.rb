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
    enums = subject.collect_enums(idx)
    nu = enums[:name_use]
    nu[:kind] == :enum
    nu[:name] == :name_use
    nu[:options].should include('usual')
  end

  example do
    pending
    db = subject.mk_db(xml)
  end
end
