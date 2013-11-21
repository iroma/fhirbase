require 'spec_helper'

describe FhirPg::Extensions do
  subject { described_class }

  let(:types_xml) { FhirPg::Xml.load('test/fhir-base.xsd') }

  let(:types_db) { FhirPg::Datatypes.mk_db(types_xml) }

  let(:resources_xml) { FhirPg::Xml.load('test/adt.xml') }

  let(:resources_db) { FhirPg::Resources.mk_db(resources_xml, types_db) }

  let(:xml) { FhirPg::Xml.load('test/extension.xml') }

  let(:db) { subject.mk_db(xml, resources_db) }

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
          a.should_not be_nil
        end
      end
    end
  end
end
