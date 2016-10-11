# Argot : a Ruby gem for TRLN shared discovery ingest processes

If you have a full ruby development environment installed, `rdoc lib/` 
will get you started.

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

## Dependencies

This gem relies on the `nokogiri`, `yajl-ruby`, `traject`, and `lisbn` gems to
be installed.  This means you'll need system packages such as `libxml2-devel`,
`lisbxslt-devel`, and `yajl` installed.

### Utilities

`Argot::XML::EventParser` - parser that handles large record-oriented XML files
one record at a time.
 
See also `Argot::TrajectJSONWriter` for a Traject JSON writer that produces
'flat' values where the traditional writers produce arrays.

#### Ideas

There are no binaries/command-line tools yet, but that's seeming like a good
idea at the moment.

#### Yes, I know

Tests are currently broken.  This format is currently in development and so are these tools!
