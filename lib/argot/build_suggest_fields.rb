module Argot
  module BuildSuggestFields
    def self.suggest_config
      @suggest_config ||= YAML.load_file(File.join(File.expand_path('../data', __dir__), 'solr_suggest_config.yml'))
    end

    # Adds values to the configured suggest fields
    # @param [Hash] flattened_fields (the hash being built for the flattened output)
    # @param [String] field_key (the name of the field being processed)
    # @param [String] value (the value associated with the field_key)
    def self.add_value_to_suggest(flattened_fields, field_key, value)
      if suggest_config.key?(field_key)
        suggest_fields = suggest_config.fetch(field_key, {}).fetch('suggest_fields')
        suggest_fields.each do |field|
          flattened_fields["#{field}_suggest"] ||= []
          flattened_fields["#{field}_suggest"] << value unless value.empty?
        end
      end
      flattened_fields
    end
  end
end
