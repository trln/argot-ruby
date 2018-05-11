module Argot
  class FlattenMiscId

    # Argot Format for use with FlattenMiscId
    #
    # misc_id:
    #   value: string|required|will be indexed and stored for display unless display is set to false.
    #   type: string|optional|prefixed as a label to the value if display is not false.
    #   qualifier: string|optional|appended as a qualifier to the value if display is not false
    #   display: boolean|optional[defaults to "true" if not set to "false"]|if "false" value will be indexed only
    def self.flatten(value, key)
      flattened = {}
      stored_values = []
      indexed_values = []

      value.each do |v|
        unless v.fetch('display', 'true') == 'false'
           str = [v.fetch('type', ''), v.fetch('value', '')].select { |s| !s.empty? }.join(': ')
           str = "#{str} (#{v.fetch('qual', '')})" if v.has_key?('qual')
           stored_values << str
        end

        indexed_values << v.fetch('value', nil)
      end

      flattened[key] = stored_values unless stored_values.empty?
      flattened["#{key}_indexed"] = indexed_values.select { |v| !v.empty? }
                                                  .compact unless indexed_values.empty?

      flattened
    end
  end
end
