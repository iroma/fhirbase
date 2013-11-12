require 'spec_helper'

describe FhirPg::Meta do
  subject { described_class }
  example do
    -> {
      described_class.mk_meta(ups: :dups)
    }.should raise_error(/key not found/)

    described_class.mk_meta(name: 'name',
                            path: 'a.b',
                            type: 'type',
                            kind: :complex_type)

    -> {
      described_class.mk_meta(name: 'name',
                              path: 'a.b',
                              type: 'type',
                              extra: 'ups',
                              kind: :complex_type)
    }.should raise_error(/Extra keys/)
  end
end
