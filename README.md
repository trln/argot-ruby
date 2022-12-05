# Argot : a Ruby gem for TRLN shared discovery ingest processes

This gem provides libraries and command-line utilities for working with Argot, the ingest format for
the TRLN shared index.

# Installation

Start with

    $ bundle install

(as long as you have the `bundler` gem available) will install all the dependencies. then

    $ bundle exec rake spec

or even just

    $ bundle exec rake

Will run the tests.

    $ bundle exec rake install 
    
will install the gem.

This gem is supported under both MRI and JRuby, but for small input files
especially, MRI is likely to be faster.  No optimizations are yet in place to
take advantage of multithreading under JRuby.

## Container-Based development

A `docker-compose.yml` file is provided that allows for developing in a
container. Start the container with

    $ docker-compose up

This will start two containers, one for argot (using essentially a no-op, but
the container stays up) and one for redis, which allows working with a running
instance of Redis to handle name authority processing features. To connect to
the running `argot` container, use

    $ docker exec -it -w /app argot /bin/bash

(a `docker.sh` script is provided, along with a `podman.sh` script)` that
checks for a running container and starts it if necessary, then runs the
appropriate `exec` command to give you a running shell in the container)

Note that by default the container build for `argot` does not run any `bundler`
commands so you have to fetch and install the gems.

The redis container (named `argot-redis` by the compose script) will open
a random port on the host, so if you need to connect to it from the host, run

    $ docker port argot-redis

To see which port got mapped.

If you want to develop on the host, all you need to do is either avoid
authority processing related operations, or run redis on the host.

## Usage 

### As Library
```ruby

require 'json' # only required for the example
require 'argot'

# new reader for processing files in the Argot format
# with default validator using rules in  `lib/data/rules.yml`
# with default error handler that writes bad records and the error report
# to stdout

File.open("nccu-2015101201320.json") do |f|
    reader = Argot::Reader.new(f)
    File.open( "some-output.dat" ) do |output|
        reader.each do |rec|
            output.write(rec.to_json)if rec['id'].start_with?("NCCU")
        end
    end
end
```

## CLI

You do not need to run `rake install` to install the gem and its associated CLI
utility `argot` into your path to use this gem; it can be executed via
prepending `bundle exec` to the commands listed below, e.g.

    $ bundle exec argot flatten argot.json

vs.

    $ argot flatten argot.json

In general you should prefer the `bundle exec` version, especially when
developing, as it's clearer which version of the gem and its associated
dependencies you are using and you can edit the files under `lib/` and see an
immediate effect.

    $ argot help

Will show you the available commands.

    $ argot help [command name]

will show detailed help about a given command.

### Inputs and Outputs

Many commands accept input and output either from/to named files, or from STDIN
and STDOUT, where omitting the `input` argument (or using the `-` shortcut)
will read from STDIN, while omitting the output argument will output to STDOUT.

e.g 

    $ argot flatten < argot-notflat.json > argot-flat.json    

and

    $ argot flatten argot-notflat.json argot-flat.json    

are equivalent, but you can also do something like:

    $ my_argot_maker_that_ouputs_to_stdout | argot flatten | jq 

to avoid creating intermediate files.

If you want to read from STDIN but output to a named file, use `-` as the first argument, e.g. 

    $ my_argot_maker_that_writes_to_stdout | argot flatten - flattened.json

(although you can accomplish the same via)

    $ my_argot_maker_that_writes_to_stdout | argot flatten > flattened.json

## Splitting Large Files

To aid in creating ingest packages of a manageable size, the tool has a `split` command that takes one or more input files and writes the records in them to a series of output files that have a maximum size, e.g. if `large-argot.json` has 253,000 records, then


    $ argot split large-argot.json

Will create `add-argot-1.json, add-argot-2.json .... add-argot-13.json` in the
`argot-files` subdirectory of the current working directory (configurable via
option), where the first 12 will have 20,000 records each and the last will
have 13,000 records.  The chunk size is also configurable via option.

## Validation

    $ argot validate [input] [output]

Runs basic quality checks on the records in `input`, writing records that pass to `output`, and error messages to STDERR.  This lets you use `argot validate` as a filter, e.g.

    $ argot validate my_argot.json valid_argot.json

will result in only valid documents in `valid_argot.json`.  Note that if you use the `--all` switch (see below) the output is documents that are flattened,
suffixed, and Solr-valid, which are not suitable for ingest.  There is currently no support for retaining the original Argot in this mode.

If you just want to run the checks and not have the 'good' records appear in output, add the `-q` or `--quiet` option.

To run a full check against Argot output generated from `marc-to-argot` to the Solr documents as they are generated by `trln-ingest` application, you can run
`validate` with the `--all` or `-a` switch, which is an alias for the 
`full_validate` command.  Note that the `full_validate` command always uses
thebundled solr schema (see below).

To aid in low-level debugging, there is a `solrvalidate` command:

    $ argot solrvalidate flattened-and-suffixed-document.json

Attempts to validate a flattened and suffixed (i.e. ready to be sent to Solr)
document against the schema.  Currently, this mostly involves checking that
single-valued fields do not have multiple values, and that numeric and date
fields match the formats required for Solr fields.  This command will exit with
an error status if any of the documents fail to validate.  If you want the
valid documents to be sent to STDOUT, pass in the `-c/--cull` option.

The schema used in `solrvalidate` is loaded from in order of preference:

1. `.argot-solr-schema.xml` in the current working directory
1. `.argot-solr-schema.xml` in the user's home directory
1. The `solr_schema.xml` bundled with the gem (`lib/data/solr_schema.xml` in the repository)

You may also specify a location on the filesystem or the base URL of the Solr
collection (e.g. `https://localhost:8983/solr/trlnbib`) to read the schema
from; this is mostly helpful for when the schema has changed and you're trying
to see whether a document's validation status is affected.

You may download a fresh copy of the schema and store it in the first of the
above listed locations (allowing you to copy it to the user's home directory,
if you so choose) by using the `schemaupdate` command.

## Ingest (Development only)

Sometimes you'll want to ingest your Argot files directly into Solr, e.g. when
you're developing a new feature and don't want to set up an ingest application.

    $ argot ingest some-argot.json 

Will flatten and suffix the records in the named files and send them to
`http://localhost:8983/solr/trln`.  You can configure the URL and size of the
batches in which documents are committed to Solr via options.  See `argot help
ingest` for more details.

## Name Authority Processing

Many of the above commands accept an `--authorities` or `-a` switch that turns
on name authority processing (un-suffixed, un-flattened Argot records are
searched for `name` entries that contain LCNAF `id` attributes, and if they
match records in a Redis database, variant names associated with that ID are
added to the output.

Authority processing assumes a Redis database is available; by default, it is
assumed to be running on `localhost` (or on a container accessible via
`host.containers.internal`) on port 6379 and to require no authentication.
You can provide a custom URL via the `REDIS_URL` environment variable or 
the `--redis_url` argument (checked in that order).

## Documentation

To build the documentation, I suggest YARD.

    $ gem install yard
    $ gem install redcarpet # may need a different markdown parser under jruby
    $ yard

This will create files in `doc/`

### MRI

 * [`yajl-ruby`](https://github.com/brianmario/yajl-ruby) -- JSON support
 
To support this, you'll need the `yajl` system package installed.

### JRuby

 * `jar-dependencies` 

Also uses `noggit`, the Java-based JSON parser from Solr, to process JSON;
import and use should be handled for you automatically.
