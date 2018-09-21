module Argot
  class FlattenTitleMain < TypeFlattener
    def flatten(value, key)
      flattened = {}
      stored ||= []

      value.each do |v|
        flattened["#{key}_indexed"] ||= []
        if v.has_key?('lang')
          flattened["#{key}_vernacular_value"] ||= []
          flattened["#{key}_vernacular_lang"] ||= []
        end

        stored << v['value']

        if v.has_key?('lang') && v.has_key?('value')
          flattened["#{key}_vernacular_value"] << v['value']
          flattened["#{key}_vernacular_lang"] << v['lang']
        else
          flattened["#{key}_indexed"] << v['value'] if v.has_key?('value')
        end

        if v.has_key?('value')
          Argot::BuildSuggestFields.add_value_to_suggest(flattened, key, v['value'])
        end
      end

      flattened["#{key}_value"] = stored.reverse.uniq.join(' / ')
      flattened.delete_if { |k,v| v.empty? }
    end
  end
end
