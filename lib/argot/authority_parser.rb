module Argot

  # Processes Library of Congress name authority files (lcnaf) in
  # "newline delimited JSON" (ndjson) format into simple hashes that
  # map shortened forms of the IDs for authority records to arrays of 
  # variant names corresponding to the supplied ID.
  # Sample Usage:
  # File.open('lcnaf.ndjson') do |f| 
  #   AuthorityParser.new(f).each do |rec|
  #     redis.put(rec[:id], rec[:label])
  #   end
  # end
  class AuthorityParser

    def initialize(stream)
      @stream = stream
    end

    def each
      return enum_for(:each) unless block_given?
      Argot::Reader.new(@stream).each do |rec|
        rdf = rec.fetch('@graph', [])
        names = name_entries(rdf) if rdf
        names.each do |name|
          if name
            id = name.fetch('@id', '')
                     .sub('http://id.loc.gov/authorities/names/', 'lcnaf:')
          end
          ids = variant_ids(name) if name
          labels = variant_labels(rdf, ids)
          unless labels.nil? || labels.empty?
            h = { id: id, labels: labels }
            yield h
          end
        end
      end
    end

    private

    def name_entries(rdf)
      rdf.select do |v|
        v.fetch('@type', []).include?('madsrdf:Authority') &&
          (v.fetch('@type', []).include?('madsrdf:PersonalName') ||
          v.fetch('@type', []).include?('madsrdf:CorporateName'))
      end
    end

    def variant_ids(name)
      return if name.nil? || name.empty?

      variants = name&.fetch('madsrdf:hasVariant', [])
      [variants]&.flatten&.map { |v| v['@id'] }
    end

    def variant_labels(rdf, ids)
      return unless ids

      ids = rdf.select { |r| ids.include?(r['@id']) }
      labels = ids.map { |f| f['madsrdf:variantLabel'] }
      labels.map { |q| q.respond_to?(:fetch) ? q.fetch('@value', nil) : q }
    end
  end
end
