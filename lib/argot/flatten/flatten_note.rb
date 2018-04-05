module Argot
  class FlattenNote
    # This note flattener will be used in place of FlattenDefault
    # when an argot field is configured to use it
    # in config file lib/argot/data/flattener_config.yml
    #
    # e.g. the following lines instruct argot-ruby to use
    # FlattenNote for the note_performer_credits field
    #
    # note_performer_credits:
    #   flattener: note
    #
    #
    # Argot Format for use with FlattenNote
    #
    # note_field:
    #   label: string|optional|"label" will be prefixed to "value" for display only
    #   value: string|required|will be stored for display and indexed unless "indexed" == false
    #                          OR "indexed_value" is provided
    #   indexed_value: string|optional|if present "indexed_value" will be indexed instead of "value"
    #   indexed: boolean|optional[defaults to "true" if not set to "false"]|if "false"
    #                                                                       "value"/"indexed_value" will not
    #                                                                       be added to the *_indexed field

    # FlattenNote.flatten output may result in two fields from a single argot field:
    #
    # This Argot:
    #
    # "note_performer_credits":[
    #   {"label":"Cast","value":"Ronald Colman, Elizabeth Allan, Edna May Oliver."},
    #   {"value":"This should be displayed only", "indexed_value": "This should be indexed instead"},
    #   {"value":"This should be displayed only, too", "indexed": "false"}]
    #
    # Will be flattend to two separate fields:
    #
    # "note_performer_credits":[
    #   "Cast: Ronald Colman, Elizabeth Allan, Edna May Oliver.",
    #   "This should be displayed only",
    #   "This should be displayed only, too"],
    # "note_performer_credits_indexed":[
    #   "Ronald Colman, Elizabeth Allan, Edna May Oliver.",
    #   "This should be indexed instead"]
    #
    # NOTE:
    #
    # note_performer_credits will automatically be stored without
    # any further configuration
    #
    # note_performer_credits_indexed must be configured in
    # lib/argot/data/solr_fields_config.yml as an indexed field,
    # otherwise it will be stored only
    #
    def self.flatten(value, key)
      flattened = {}
      stored_values = []
      indexed_values = []

      value.each do |v|
        stored_values << [v.fetch('label', ''), v.fetch('value', '')].select { |e| !e.empty? }.join(': ')

        if v.fetch('indexed', 'true') == 'true'
          indexed_values << (v.fetch('indexed_value', false) || v.fetch('value', ''))
        end
      end

      flattened[key] = stored_values
      flattened["#{key}_indexed"] = indexed_values unless indexed_values.empty?

      flattened
    end
  end
end
