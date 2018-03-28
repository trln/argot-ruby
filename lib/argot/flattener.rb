##
# Flattens nested Argot JSON
module Argot

  # Flattens an argot hash
  class Flattener

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
      when 'note'
        Argot::FlattenNote
      else
        Argot::FlattenDefault
      end
    end
  end
end