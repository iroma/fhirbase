require 'spec_helper'

describe FhirPg::Repository do
  subject { described_class.new(DB, 'fhir') }

  def load_json(name)
    file = File.dirname(__FILE__) + "/fixtures/#{name}.json"
    ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(File.read(file)))
  end

  example do
    pt = load_json('pt1')
    pt = subject.save(pt)
    pt[:id].should_not be_nil

    saved_pt = subject.find(pt[:id])
    saved_pt[:id].should == pt[:id]

    saved_pt[:name].first[:family].should match(/van de/)

    # saved_pt.should == pt
  end
end
