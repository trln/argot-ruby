module Argot
  class FlattenNames < TypeFlattener
    def flatten(value, key)

      flattened = {}
      facet_values = []
      stored_values = []

      value.each do |v|
        if %w[director creator editor contributor no_rel].include? v.fetch('type', '')
          facet_values << v.fetch('name', nil)
        end

        stored_value = { 'name' => v.fetch('name', '') }
        stored_rel = v.fetch('rel', []).join(', ')
        stored_value['rel'] = stored_rel unless stored_rel.empty?
        stored_values << stored_value.to_json

        indexed_key = "#{key}_#{v.fetch('type', 'no_rel')}"
        indexed_value = v.fetch('name', '')
        flattened[indexed_key] ||= []
        flattened[indexed_key] << indexed_value unless indexed_value.empty?

        Argot::BuildSuggestFields.add_value_to_suggest(flattened, key, indexed_value)
      end

      flattened["author_facet"] = facet_values.compact unless facet_values.empty?
      flattened[key] = stored_values.compact unless stored_values.empty?

      flattened
    end
  end
end
