require 'spec_helper'

describe FhirPg::Extensions do
  subject { described_class }

  let(:xml) {
    FhirPg::Xml.load('test/extension.xml')
  }

  example do
   puts subject.send(:mk_db, xml)
   puts subject.schema(xml)
  end
end
