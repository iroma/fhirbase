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
end
