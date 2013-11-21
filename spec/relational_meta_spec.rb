require 'spec_helper'
require 'uuid'

describe FhirPg::Relational do
  subject { described_class }

  def rfile(path)
    File.read(File.dirname(__FILE__) + "/#{path}")
  end

  example do
    dt_xml = FhirPg::Xml.load('test/fhir-base.xsd')
    xml = FhirPg::Xml.load('test/profiles-resources.xml')
    subject.mk_db(DB, dt_xml, xml)
  end

  example do
    subject.dataset(DB, :complex_types).all.should_not be_empty
  end

  example do
    subject.dataset(DB, :enums).all.should_not be_empty
  end

  example do
    subject.dataset(DB, :primitives).all.should_not be_empty
  end
end
