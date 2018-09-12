module Argot
  class FlattenTitleVariant < TypeFlattener

    # Argot Format for use with FlattenTitleVariant
    #
    # title_variant_field:
    #   label: string|optional|"label" will be prefixed to "value" for display only
    #   type: string|optional[defaults to 'variant']|Used to construct flattened field name (title_#{type}_*)
    #   value: string|required|will be stored for display and indexed unless "indexed_value" is provided
    #   indexed_value: string|optional|if present "indexed_value" will be indexed instead of "value"
    #   issn: string|optional|stored separately for indexing and also appended to display value
    #   display: boolean|optional[defaults to "true" if not set to "false"]|if "false" value will be indexed only
    def flatten(value, _)
      flattened = {}

      value.each do |v|
        key = "title_#{v.fetch('type', 'variant')}"

        flattened[key] ||= []
        flattened["#{key}_indexed"] ||= []
        flattened["#{key}_issn"] ||= []

        if v.fetch('display', 'true') == 'true'
          display_v = ''
          display_v << "#{v['label']}: " if v.has_key?('label')
          display_v << v['value'] if v.has_key?('value')
          display_v << ". ISSN: #{v['issn']}" if v.has_key?('issn')
          flattened[key] << display_v
        end

        indexed_value = v.fetch('indexed_value', false) || v.fetch('value', '')
        flattened["#{key}_indexed"] << indexed_value
        Argot::BuildSuggestFields.add_value_to_suggest(flattened, key, indexed_value)

        if v.has_key?('issn')
          flattened["#{key}_issn"] << v.fetch('issn', '')
        end
      end

      flattened.delete_if { |k,v| v.empty? }
    end
  end
end
