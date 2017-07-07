require 'argot/meta'

# Argot is TRLN's shared ingest format; it is a dialect of JSON, and
# represents (primarily) a tranformation of MARC into a more human-readable
# format close to what might be ingested directly into Solr.
module Argot
  autoload :Reader, 'argot/reader'
  autoload :Pipeline, 'argot/pipeline'
  autoload :Flattener, 'argot/flattener'
  autoload :Suffixer, 'argot/suffixer'
  autoload :Validator, 'argot/validator'
  autoload :SolrSchema, 'argot/solr_schema'
end
