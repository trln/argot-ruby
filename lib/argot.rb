require 'argot/meta'
if RUBY_PLATFORM =~ /java/
  require 'argot/jruby/reader'
else
  require 'argot/mri/reader'
end
require 'argot/pipeline'
require 'argot/flattener'
require 'argot/suffixer'
require 'argot/validator'

# Argot is TRLN's shared ingest format; it is a dialect of JSON, and
# represents (primarily) a tranformation of MARC into a more human-readable
# format close to what might be ingested directly into Solr.
module Argot
end
