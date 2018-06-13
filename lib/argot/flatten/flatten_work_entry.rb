module Argot
  class FlattenWorkEntry < TypeFlattener

    # Argot Format for use with FlattenWorkEntry
    #
    # work_enrty_field:
    #  type: STRING|required|determines flattened field names
    #  author: STRING|optional
    #  title: ARRAY|optional
    #  title_nonfiling: STRING|optional
    #  title_variation: STRING|optional
    #  isbn: ARRAY|optional
    #  issn: STRING|optional
    #  other_ids: ARRAY|optional
    #  display: STRING[true|false]|optional[default: true]

    def flatten(value, _)
      flattened = {}

      value.each do |v|
        key = v.fetch('type', 'included')

        flattened["#{key}_author"] ||= []
        flattened["#{key}_title"] ||= []
        flattened["#{key}_isbn"] ||= []
        flattened["#{key}_issn"] ||= []
        flattened["#{key}_other_ids"] ||= []
        flattened["#{key}_work_indexed"] ||= []
        flattened["#{key}_work"] ||= []

        if v.fetch('display', 'true') == 'true'
          display_v = {}
          display_v[:label] = v['label'] if v.has_key?('label')
          display_v[:author] = v['author'] if v.has_key?('author')
          display_v[:title] = v['title'] if v.has_key?('title')
          display_v[:title_variation] = v['title_variation'] if v.has_key?('title_variation')
          display_v[:isbn] = v['isbn'] if v.has_key?('isbn')
          display_v[:issn] = v['issn'] if v.has_key?('issn')

          flattened["#{key}_work"] << display_v.to_json
        end

        flattened["#{key}_work_indexed"] << [v.fetch('author', ''),
                                             v.fetch('title', []).join(' ')].join(' ').strip
        flattened["#{key}_author"] << v.fetch('author', '') if v.has_key?('author')
        flattened["#{key}_title"] << v.fetch('title', []).join(' ') if v.has_key?('title')
        flattened["#{key}_title"] << v.fetch('title_nonfiling', '') if v.has_key?('title_nonfiling')
        flattened["#{key}_title"] << v.fetch('title_variation', '') if v.has_key?('title_variation')
        flattened["#{key}_isbn"].concat(v.fetch('isbn', [])) if v.has_key?('isbn')
        flattened["#{key}_issn"] << v.fetch('issn', '') if v.has_key?('issn')
        flattened["#{key}_other_ids"].concat(v.fetch('other_ids', [])) if v.has_key?('other_ids')
      end

      flattened.delete_if { |k,v| v.empty? }
    end
  end
end
