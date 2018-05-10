require 'yaml'

##
# Flattens nested Argot JSON
module Argot

  # Flattens an argot hash
  class Flattener

    def self.default_config
      data_load_path = File.expand_path('../data', File.dirname(__FILE__))
      flattener_config = YAML.load_file(data_load_path + '/flattener_config.yml')
      flattener_config
    end

    def self.combine(hash1, hash2)
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

    def self.process(input, config = {})
      config = default_config if config.empty?
      flattened = {}

      input.each do |k, v|
        flattened = combine(flattened, flatten_klass(k, config).flatten(v, k)) unless v.nil?
      end

      flattened.each do |k, v|
        flattened[k] = v[0] if v.length == 1
      end
    end

    def self.flatten_klass(key, config = {})
      case config.fetch(key, {}).fetch('flattener', '')
      when 'misc_id'
        Argot::FlattenMiscId
      when 'note'
        Argot::FlattenNote
      when 'title_variant'
        Argot::FlattenTitleVariant
      else
        Argot::FlattenDefault
      end
    end
  end
end