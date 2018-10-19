module Argot
  class FlattenIndexedValue < TypeFlattener
    def flatten(value, key)
      flattened = {}
      stored_values = []
      indexed_values = []
      vern_values = []
      vern_langs = []

      value.each do |v|
        stored_values << [v.fetch('label', ''), v.fetch('value', '')].select { |e| !e.empty? }.join(': ')
        if v.has_key?('lang')
          vern_values << v.fetch('value', '')
          vern_langs << v.fetch('lang', '')
        else
          indexed_values << v.fetch('value', '')
        end
      end

      flattened[key] = stored_values
      flattened["#{key}_indexed"] = indexed_values unless indexed_values.empty?
      flattened["#{key}_indexed_vernacular_value"] = vern_values unless vern_values.empty?
      flattened["#{key}_indexed_vernacular_lang"] = vern_langs unless vern_langs.empty?

      flattened
    end
  end
end
