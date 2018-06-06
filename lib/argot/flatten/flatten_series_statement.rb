module Argot
  class FlattenSeriesStatement
    def self.flatten(value, key)
      flattened = {}
      stored_values = []
      indexed_values = []
      issns = []
      other_ids = []

      value.each do |v|
        stored_values << [v.fetch('label', ''), v.fetch('value', '')].select { |e| !e.empty? }.join(': ')
        indexed_values << v.fetch('value', '')
        issns.concat v.fetch('issn', [])
        other_ids.concat v.fetch('other_ids', [])
      end

      flattened[key] = stored_values unless stored_values.empty?
      flattened["#{key}_indexed"] = indexed_values unless indexed_values.empty?
      flattened["#{key}_issn"] = issns unless issns.empty?
      flattened["#{key}_other_ids"] = other_ids unless other_ids.empty?
      flattened
    end
  end
end
