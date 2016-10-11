require 'set'
##
# Subclass of Traject::JsonWriter that converts the values of top-level attributes
# of the current record to scalars, which is the form expected by Argot.
class Argot::TrajectJSONWriter < Traject::JsonWriter

    @@array_fields = %w[collection holdings].to_set

    def serialize(context)
        flatten_record!(context.output_hash)
        super(context)
    end

    private 


    def flatten_record!(rec)
        rec.each do |key,value| 
            if not @@array_fields.include?(key) 
                if value.is_a?(Array)
                    rec[key] = value[0]
                end
            end
        end
    end
end