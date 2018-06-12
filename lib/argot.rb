require 'argot/meta'

# Argot is TRLN's shared ingest format; it is a dialect of JSON, and
# represents (primarily) a tranformation of MARC into a more human-readable
# format close to what might be ingested directly into Solr.
module Argot
  autoload :Reader, 'argot/reader'
  autoload :Pipeline, 'argot/pipeline'
  autoload :Transformer, 'argot/pipeline'
  autoload :Filter, 'argot/pipeline'
  autoload :Flattener, 'argot/flattener'
  autoload :FlattenDefault, 'argot/flatten/flatten_default'
  autoload :FlattenIndexedValue, 'argot/flatten/flatten_indexed_value'
  autoload :FlattenMiscId, 'argot/flatten/flatten_misc_id'
  autoload :FlattenNote, 'argot/flatten/flatten_note'
  autoload :FlattenSeriesStatement, 'argot/flatten/flatten_series_statement'
  autoload :FlattenTitleVariant, 'argot/flatten/flatten_title_variant'
  autoload :FlattenWorkEntry, 'argot/flatten/flatten_work_entry'
  autoload :Suffixer, 'argot/suffixer'
  autoload :Validator, 'argot/validator'
  autoload :SolrSchema, 'argot/solr_schema'
end
