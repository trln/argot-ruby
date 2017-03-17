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

Will run the tests.

    $ rake install 
    
will install the gem.

This gems is supported under both MRI and JRuby, but for small input files
especially, MRI is likely to be faster.  No optimizations are yet in place to
take advantage of multithreading under JRuby.

## Usage 

### As Library
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

After installing the gem, you can run `argot help` to see the available commands.
Many commands accept input and output either from/to named files, or from STDIN and STdOUT, where
omitting the `input` argument (or using the `-` shortcut) will read from STDIN, while omitting the 
output argument will output to STDOUT.

e..g 

    $ argot flatten < argot-notflat.json > argot-flat.json
    
and

    $ argot flatten argot-notflat.json argot-flat.json
    
are equivalent, but you can also do something like:

    $ my_argot_maker_that_ouputs_to_stdout | argot flatten | jq 

to avoid creating intermediate files.

If you want to read from STDIN but output to a named file, use `-` as the first argument, e.g.

    $ my_argot_maker_that_writes_to_stdout | argot flatten - flattened.json
    
## Documentation

To build the documentation, I suggest YARD.  

    $ gem install yard
    $ gem install redcarpet # may need a different markdown parser under jruby
    $ yard

This will create files in `doc/`

## Dependencies (Gems)

All Platforms:

 * [`traject`](https://github.com/traject/traject)

### MRI

 * [`yajl-ruby`](https://github.com/brianmario/yajl-ruby) -- JSON support
 
To support this, you'll need the `yajl` system package installed.

### JRuby

 * `jar-dependencies` 

Also uses `noggit`, the Java-based JSON parser from Solr, to process JSON;
import and use should be handled for you automatically.

### Utilities

See also `Argot::TrajectJSONWriter` for a Traject JSON writer that produces
'flat' values where the traditional writers produce arrays.
