require 'spec_helper'

describe FhirPg::Xml do
  subject { described_class }

  it "should load from vendor" do
    xml = subject.load('test/fhir-base.xsd')
    xml.should_not be_nil
  end
end
