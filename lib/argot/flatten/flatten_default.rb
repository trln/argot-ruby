module Argot
  class FlattenDefault
    def self.flatten(value, parent, ignore = nil)
      flattened = {}

      if value.is_a?(Hash)
        value.each do |k,v|
          expanding_key = "#{parent}_#{k}"
          flattened = Argot::Flattener.combine(flattened, flatten(v, expanding_key))
        end
      elsif value.is_a?(Array) and value[0].is_a?(Hash)
        value.each do |v|
          flattened = Argot::Flattener.combine(flattened, flatten(v, parent))
        end
      else
        unless value.nil?
          flattened[parent] = [] if flattened[parent].nil?
          flattened[parent] << value
        end
      end
      flattened
    end
  end
end
