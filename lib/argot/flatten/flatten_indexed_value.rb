module Argot
  class FlattenIndexedValue
    def self.flatten(value, key)
      flattened = {}
      stored_values = []
      indexed_values = []

      value.each do |v|
        stored_values << [v.fetch('label', ''), v.fetch('value', '')].select { |e| !e.empty? }.join(': ')
        indexed_values << v.fetch('value', '')
      end

      flattened[key] = stored_values
      flattened["#{key}_indexed"] = indexed_values unless indexed_values.empty?

      flattened
    end
  end
end
