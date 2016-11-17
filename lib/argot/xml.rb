#!/usr/bin/env ruby

# note for this to work nokogiri (XML processing) and lisbn gems
# need to be installed; nokogiri uses libxml2 and libxslt native
# libraries so on linux make sure that the -devel packages are installed
# along with development tools such as a C/C++ compiler 
#
require 'nokogiri'
require 'argot/ice_extractor'

##
# This module contains various tools for processing \XML
#
# EventParser
#
# ICEExtractor
module Argot::XML 
    
    # Implementation of a SAX Parser that yields a +Nokogiri::XML::Element++
    # instance as each end tag is encountered in the source document and invokes
    # a handler for each one.
    
    # Allows memory-efficient iteration over large record-oriented
    # XML files while still allowing use of Nokogiri's API to query
    # and update the structure of returned elements
    
    # If the `tag` parameter is supplied, will only yield 
    # elements matching the supplied name
    
    # Depending on you you supply it, a +handler+ can be anything with 
    # a +.call(element)+ method, which includes blocks, lambdas, and 
    # procs.  If you have a standalone function created with +def+,
    # you should use the +#handle=+ variant and the +method(:[symbol])
    # builtin, e.g.
    #   def myhandler(el) 
    #     # process el
    #    end
    #   parser.handler = method(:myhandler)
     
    # Alternately, if your handler requires some internal state:
     
    #   class MyHandler
    #     def initialize(file)
    #       @file = File.new(file)
    #     end
          
    #     def call(el)
    #       @file.write(el.to_s)
    #     end
    #   end
     
    #   parser.handler = MyHandler.new("/tmp/out.xmlish")
    # @!attribute context the current nested path of element names
    # @!attribute current the element currently being built
    # @!attribute tag the tag containing the records of interest.
    # @!attribute handler a #call-able that will process each element
    # @!attribute current_doc (for internal use only) handles
    class EventParser < Nokogiri::XML::SAX::Document

        attr_accessor :context, :current, :tag, :handler
        
        # Creates a new instance
        #
        # Parameters:
        #
        # +tag+ the tag to look for 
        # 
        # +block+ the block to be executed as each record's end element
        # is encountered (optional)
        # 
        # Usage:
        #
        #   # block is optional
        #   parser = Argot::XML::EventParser.new("record") do 
        #     |rec|
        #     ... process record
        #   end
        # See the +#handler+ methods
        def initialize(tag='*', options={}, &block)
            @context = []
            @tag = tag
            if block_given?
                @handler = block
            elsif options[:handler]
                @handler = options[:handler]
            else
                @handler = -> (el) {el}
            end
        end

        # get the current context of the document
        # from the current element up to the root, with each
        # element name separated by a `/`
        def show_context() 
            @context.join("/")
        end

        private

        attr_accessor :current_doc
        
        def start_element(name, attributes=[])#:nodoc
            @context.push(name)
            if @tag != '*'    
                if @current_doc.nil?
                    @current_doc = Nokogiri::XML::Document.new
                end
                el = Nokogiri::XML::Element.new(name,@current_doc)
                attributes.each do |attr|
                    el.set_attribute(attr[0],attr[1])
                end
                if @tag == name
                    @current = el
                elsif @current
                    el.parent = @current
                    @current = el
                end
            end
        end

        def text_node(string)
            Nokogiri::XML::Text.new(string,@current_doc)
        end

        def characters(string)
            if not @current.nil?
                @current.add_child( text_node(string))
            end
        end

        def end_element(name)
            if name == @tag
                @handler.call @current
                @current_doc = nil
                @current = nil
            elsif @current
                @current = @current.parent
            end
            @context.pop
        end
    end
end
