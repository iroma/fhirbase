require 'spec_helper'

describe FhirPg::Resources do
  subject { described_class }

  let(:xml) {
    FhirPg::Xml.load('test/adt.xml')
  }

  let(:types_db) {
    FhirPg::Datatypes.mk_db(
      FhirPg::Xml.load('test/fhir-base.xsd'))
  }

  let(:db) {
    subject.mk_db(xml, types_db)
  }

  example do
    pt =  db[:patient]
    pt[:name].should == :patient
    pt[:kind].should == :resource
    pt[:attrs].should_not be_empty

    gender = pt[:attrs][:gender]
    gender[:kind].should == :complex_type
    gender[:type].should == :codeable_concept
    cd = gender[:attrs][:coding]
    cd[:path].should == 'patient.gender.coding'
    cd[:attrs][:system][:kind].should == :primitive
    cd[:attrs][:system][:path].should == 'patient.gender.coding.system'


    dec = pt[:attrs][:deceased_boolean]
    dec[:kind].should == :primitive
    dec[:path].should == 'patient.deceased_boolean'
  end

  example do
    pt = db[:patient]
    pt[:name].should == :patient
    pt[:path].should == 'patient'
    pt[:attrs].should_not be_empty

    bd_col = pt[:attrs][:birth_date]
    bd_col.should be_present
    bd_col[:kind].should == :primitive
    bd_col[:collection].should be_false

    #todo may be this should go to embeds
    ms_col = pt[:attrs][:marital_status]
    ms_col[:kind].should == :complex_type
    ms_col[:type].should == :codeable_concept
    cs =  ms_col[:attrs][:coding][:attrs][:system]
    cs[:path].should == 'patient.marital_status.coding.system'
    cs[:kind].should == :primitive

    cnt =  pt[:attrs][:contact]
    cnt.should_not be_nil
    cnt[:collection].should be_true
    cnt[:kind].should == :complex_type

    cn = cnt[:attrs][:name]
    cn[:kind].should == :complex_type
    cn[:type].should == :human_name
    cn[:path].should == 'patient.contact.name'
    cn[:attrs][:period][:path].should == 'patient.contact.name.period'
    pt[:attrs][:address][:attrs][:city][:path].should == 'patient.address.city'


    name = pt[:attrs][:name]
    name[:attrs][:family].should_not be_nil
  end
end
