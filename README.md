# Argot : a Ruby gem for TRLN shared discovery ingest processes

This gem provides libraries and command-line utilities for working with Argot, the ingest format for
the TRLN shared index.

# Installation

Start with

    $ bundle install

(as long as you have the `bundler` gem available) will install all the dependencies. then


    $ rake test

or even just

    $ rake

Will run the tests, but you can't use `rake install` yet.  Installation should be as easy as

    $ gem build argot.gemspec
    $ gem install argot-0.0.8.gem # or whatever version it is currently
    $ gem install argot-0.0.8.gem # or whatever version it is currently, argot-0.0.8-java.gem if using jruby

As of v0.0.4, this gem is supported under both MRI and JRuby.  For small files
especially, MRI is likely to be faster, and we have not
done any optimizations to take advantage of multithreading under JRuby yet.

## Usage 
```ruby

require 'json' # only required for the example
require 'argot'

# new reader for processing files in the Argot format
# with default validator using rules in  `lib/data/rules.yml`
# with default error handler that writes bad records and the error report
# to stdout
reader = Argot::Reader.new

output = File.new( "some-output.dat" ) 
# use a block to handle each (valid) record as its processed

reader.process( File.new("nccu-20161012101320.dat") ) do |rec|
    output.write( rec.to_json )
end
```
## CLI

After installing the gem (`gem build argot.gemspec; gem install argot`), you can run `argot help` to see the available commands.

## Documentation

To build the documentation, I suggest YARD.  

    $ gem install yard
    $ gem install redcarpet
    $ yard

This will create files in `doc/`

## Dependencies (Gems)

All Platforms:

 * `nokogiri` (slated for removal as a direct dependency)
 * [`traject`](https://github.com/traject/traject)
 * `lisbn` (depends on nokogiri, may look for a replacement)

### MRI

 * [`yajl-ruby`](https://github.com/brianmario/yajl-ruby) -- JSON support
 
To support this, you'll need the `yajl` system package installed. Nokogiri
requires `libxml2-devel` and `libxslt-devel`.

### JRuby

 * `jar-dependencies` 

Also uses `noggit`, the Java-based JSON parser from Solr, to process JSON; import and use should be handled for you automatically.

### Utilities

`Argot::XML::EventParser` - parser that handles large record-oriented XML files
one record at a time.  (slated for removal)
 
See also `Argot::TrajectJSONWriter` for a Traject JSON writer that produces
'flat' values where the traditional writers produce arrays.

### Convert ICE to JSON

(slated for removal; see https://github.com/trln/trln-util)

 `ice_to_json`, processes XML in
the ICE format (table of contents data) into concatenated JSON output, suitable
for ingest into Solr.

    $ ice_to_json tc2349080.xml > ice_updates-$(date +%Y-%m-%d).json

The resulting file is suitable for ingesting directly into Solr, assuming you
have a suitable schema -- for testing, you can use solr's data-driven configSet and just make sure to add the ISBN field as a string, multivalued, stored, and indexed.  Then the following will serve to ingest, assuming your collection is named "icetocs":

    $ curl -H'Content-Type: application/json' --data-binary @out.json http://localhost:8983/solr/icetocs/update/json/docs
    $ curl http://localhost:8983/solr/icetocs/update?commit=true
