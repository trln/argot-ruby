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

    def self.flatten(value, parent, ignore = nil)
      flattened = {}

      if value.is_a?(Hash)
        value.each do |k,v|
          expanding_key = "#{parent}_#{k}"
          flattened = combine(flattened, flatten(v, expanding_key))
        end
      elsif value.is_a?(Array) and value[0].is_a?(Hash)
        value.each do |v|
          flattened = combine(flattened, flatten(v, parent))
        end
      else
        unless value.nil?
          flattened[parent] = [] if flattened[parent].nil?
          flattened[parent] << value
        end
      end
      flattened
    end

    def self.process(input)
      flattened = {}

      input.each do |k, v|
        flattened = combine(flattened, flatten(v, k)) unless v.nil?
      end

      flattened.each do |k, v|
        flattened[k] = v[0] if v.length == 1
      end
    end
  end

end