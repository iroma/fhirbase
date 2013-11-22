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
end
