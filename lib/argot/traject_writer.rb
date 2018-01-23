require 'set'

module Argot
  ##
  # Subclass of Traject::JsonWriter that converts the values
  # top-level attributes of the current record to scalars, which is
  # the form expected by Argot.
  class TrajectJSONWriter < Traject::JsonWriter
    @array_fields = %w[holdings url items imprint_main imprint_multiple].to_set

    def serialize(context)
      flatten_record!(context.output_hash)
      super(context)
    end

    private

    def flatten_field?(key, value)
      !@array_fields.include?(key) && value.is_a?(Array)
    end

    def flatten_record!(rec)
      rec.each do |key, value|
        rec[key] = value[0] if flatten_field?(key, value)
      end
    end
  end
end
