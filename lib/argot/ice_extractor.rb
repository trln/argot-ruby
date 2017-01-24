require 'nokogiri'
require 'lisbn'
require 'fiber'
require 'argot'

##
# Implements a handler that extracts ICE Data from Syndetics in a handy format from USMARC records.
# [rdoc-ref:Argot::XML::EventHandler]
module Argot::XML

    ICEDocument = Struct.new(:key, :isbns, :title, :chapters)
    ICEChapter = Struct.new(:title, :authors)

    class ICEExtractor

      # Create a new extractor with a source
      # @param source [String,#read] a filename or IO to read data from 
      def initialize(source)
        @parser = EventParser.new("USMARC", handler: self)
        @source = source
        @fiber = Fiber.new do
          loop do
            rec = Fiber.yield
            break unless rec
            @looper.resume rec
          end
        end
      end

        ## 
        # Normalizes an input candidate ISBN  (upcase, strip irrelevant characters)
        # and returns two values, boolean indicating validity and the normalized
        # value
        def good_isbn?(value)
            v = value.upcase().gsub(/[^0-9X]/, '')
            [ Lisbn.new(v).valid?, v ]
        end

        def marc005todate(marc_value)
            y, m, d, hr, min,sec = marc_value.unpack("a4a2a2a2a2a2").map { |x| x.to_i }
            return DateTime.new(y,m,d,hr,min,sec)
        end

      def each
        return enum_for(:each) unless block_given?
        # start the fiber that receives records from :call
        @fiber.resume true

        # create our own fiber to interact with the above
        @looper = Fiber.new do
          while rec = Fiber.yield
            yield rec
          end
        end
        # it needs a call to #resume to get going
        @looper.resume true
        p = Nokogiri::XML::SAX::Parser.new(@parser)
        input = @source.respond_to?(:read) ? @source : File.open(@source)
        p.parse(input)
      end

        ##
        # extracts a record hash from a USMARC record
        # *+rec+ a Nokogiri::XML::Element USMARC element
        # 
        # The returned hash has the following structure:
        # * +:id+ the ID assigned to the record by Syndetics 
        # * +:update_date_time+ the time the record was last updated, according to the 005
        # * +:isbn+ an array of ISBNs
        # * +:title+ the title from the 245
        # * +chapters+ : an array of hashes describing the chapters (TOC)
        # ** +:authors+ - an array of authors for the chapter (if present)0
        # ** +:title+ - the chapter title (if present)
        # @return the extracted record, nil if no useful information can be extracted
        def call(el)

          dfld = el.xpath("VarFlds/VarDFlds[1]")[0]
          ssifld = dfld.xpath("SSIFlds[1]")[0]

          isbns = dfld.xpath("NumbCode/Fld020/a/text()")
                .map    { |i| good_isbn?(i.text) }
                .select { |good,v| good }
                .map    { |t,v| v }

          return nil if ssifld.nil?

          chapters = ssifld.xpath("Fld970[@I1 != '0']").map { |field|
              d = {}
              authors = field.xpath("e|f/text()")
              titles = field.xpath("t/text()")
              d[:authors] = authors unless authors.empty?
              if not titles.nil? and titles.length > 0 and not titles[0].text.empty?
                  d[:title] = titles[0].text
              end
              d
           }.select { |d| not d.empty? }

           begin
            record_id = el.xpath("VarFlds/VarCFlds/Fld001/text()")[0].text
            update_date_time = marc005todate(el.xpath("VarFlds/VarCFlds/Fld005/text()")[0].text)
            title = dfld.xpath("Titles/Fld245/*[self::a or self::b][1]/text()")[0].text
           rescue StandardError
            # these *probably* happen when the above fields are not present. 
            #  In which case, we'll just have to Make Stuff Up(tm); for record_id, we'll 
            #  use the first ISBN we find,
            #  for update time, just use 'now'
            record_id ||= "unknown-#{isbns[0]}"
            update_date_time ||= DateTime.now
            title ||= ''
           end

          rec = {
                :id => record_id,
                :update_date_time => update_date_time,
                :isbn => isbns,
                :title => title,
                :chapters => chapters 
          }
          @fiber.resume rec
        end

    end
end
