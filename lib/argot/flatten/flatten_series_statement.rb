module Argot
  class FlattenSeriesStatement < TypeFlattener

    def flatten(value, key)
      flattened = {}
      stored_values = []
      indexed_values = []
      vern_values = []
      lang_values = []
      issns = []
      other_ids = []

      value.each do |v|
        stored_values << [v.fetch('label', ''), v.fetch('value', '')].select { |e| !e.empty? }.join(': ')
        indexed_values << v.fetch('value', '') unless v.key?('lang')
        vern_values << v.fetch('value', '') if v.key?('lang')
        lang_values << v.fetch('lang', '') if v.key?('lang')
        issns.concat v.fetch('issn', [])
        other_ids.concat v.fetch('other_ids', [])
      end

      flattened[key] = stored_values unless stored_values.empty?
      flattened["#{key}_indexed"] = indexed_values unless indexed_values.empty?
      flattened["#{key}_indexed_vernacular_value"] = vern_values unless vern_values.empty?
      flattened["#{key}_indexed_vernacular_lang"] = lang_values unless lang_values.empty?
      flattened["#{key}_issn"] = issns unless issns.empty?
      flattened["#{key}_other_ids"] = other_ids unless other_ids.empty?
      flattened
    end
  end
end
