##
# Adds Solr Suffixes to Flattened Argot
class Argot::Suffixer

	def initialize(config, solr_fields)
    @solr_fields = solr_fields
    @config = config

    if @config.key?("id")
  		logger.warn("config has no id attribute")
    end

    if @config.key?("trim")
    	unless @config[:trim].is_a(Array)
    		logger.warn("Config's trim attribute is not an array")
  		end
		end
  end

  def add_suffix(key,vernacular,lang)

		suffix = ""

		if @solr_fields[key].nil?
			suffix = "_a"
		else

			type = @solr_fields[key][:type]
			attributes = @solr_fields[key][:attr].nil? ? [] : @solr_fields[key][:attr]
			# add vernacular & language
			if vernacular
				suffix << "_v_#{lang}"
			end

			# add special sort value
			if attributes.include?("sort")
				intTypes = %w(i float long double)
				sort_suffix = intTypes.include?(type) ? "_isort" : "_ssort"
				suffix << sort_suffix
			else
				suffix << "_#{type}"
			end

			# add stored
			if attributes.include?("stored")
				suffix << "_stored"
			end

			# add single
			if attributes.include?("single")
				suffix << "_single"
			end
		end
		"#{key}#{suffix}"
	end

	def normalize_key(key)
		@config[:trim].each do |v|
			if key.end_with?("_#{v}")
				key = key.sub("_#{v}","")
			end
		end
		key
	end

	def process(input)
		suffixed = Hash.new
		unless @config[:lang].nil?
			lang = input["#{@config[:lang]}"].nil? ? "" : input["#{@config[:lang]}"];
		end
		
		input.each do |k,v|
			nKey = @config[:trim].nil? ? k : normalize_key(k)
			vernacular = false

			# If @config has a vernacular value, trim and set vernacular to true
			unless @config[:vernacular].nil?
				if nKey.end_with?("_#{@config[:vernacular]}")
					nKey = nKey.sub("_#{@config[:vernacular]}","")
					vernacular = true

					#unless v["#{nKey}_#{@config[:lang]}"].nil?
					#	lang = v["#{nKey}_#{@config[:lang]}"]
					# end
				end
			end

			if k === "#{@config[:id]}"
				solrKey = 'id'
			else
				solrKey = add_suffix(nKey,vernacular,lang)
			end

			suffixed[solrKey] = v
		end

		suffixed
	end
	
end