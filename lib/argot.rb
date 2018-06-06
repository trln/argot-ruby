# frozen_string_literal: true

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

  # Allow classes to be used as blocks
  module Methods
    # converts a hash whose keys are strings
    # one whose keys are symbols
    # ONLY AFFECTS TOP LEVEL
    def symbolize_hash(hash)
      hash.each_with_object({}) { |(k, v), m| m[k.to_sym] = v }
    end

    # shortcut to get a block that calls the instance's
    # 3call method with a single record
    def as_block
      lambda do |rec|
        call(rec)
      end
    end

    # merges hash2 into hash1, converting values
    # that are already in hash1 to arrays
    def combine(hash1, hash2)
      hash2.each do |k, v|
        if hash1.key?(k)
          hash1[k] = Array(hash1[k])
          hash1[k] = hash1[k] + v
        else
          hash1[k] = v
        end
      end
      hash1
    end

    def memoize(method_name)
      m = method(method_name.to_sym)
      memo = Hash.new { |h, key|
        h[key] = m.call(key)
      }
      lambda do args
        memo[args]
      end
    end
  end
end
