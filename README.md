# FHIRBase

Document/Relational hybryde database for FHIR

## Installation

sudo apt-get postgresql-9.3 postgresql-contrib-9.3 postgresql-plv8-9.3
cat fhirbase.sql fhirbase_spec.sql | psql -d myfhir

## TODO

* contained resources
* extensions

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
