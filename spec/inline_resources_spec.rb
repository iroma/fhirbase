require 'spec_helper'

describe FhirPg::Repository do
  subject { described_class.new(DB, 'fhir') }

  def load_json(name)
    file = File.dirname(__FILE__) + "/fixtures/#{name}.json"
    ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(File.read(file)))
  end

  example do
    FhirPg.reload_schema(DB, 'fhir')
    pt = load_json('inline_resource')
    pt = subject.save(pt)
    saved_pt = subject.find(pt['id'])

    saved_pt['contained'].should_not be_empty

    # saved_pt.should == pt
    #
  end
end
