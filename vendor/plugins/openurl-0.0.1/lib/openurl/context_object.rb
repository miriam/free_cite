module OpenURL
  
  # The ContextObject class is intended to both create new OpenURL 1.0 context
  # objects or parse existing ones, either from Key-Encoded Values (KEVs) or XML.
  # Usage:
  #   require 'openurl/context_object'
  #   include OpenURL
  #   ctx = ContextObject.new
  #   ctx.referent.set_format('journal')
  #   ctx.referent.add_identifier('info:doi/10.1016/j.ipm.2005.03.024')
  #   ctx.referent.set_metadata('issn', '0306-4573')
  #   ctx.referent.set_metadata('aulast', 'Bollen')
  #   ctx.referrer.add_identifier('info:sid/google')
  #   puts ctx.kev
  #   # url_ver=Z39.88-2004&ctx_tim=2007-10-29T12%3A18%3A53-0400&ctx_ver=Z39.88-2004&ctx_enc=info%3Aofi%2Fenc%3AUTF-8&ctx_id=&rft.issn=0306-4573&rft.aulast=Bollen&rft_val_fmt=info%3Aofi%2Ffmt%3Axml%3Axsd%3Ajournal&rft_id=info%3Adoi%2F10.1016%2Fj.ipm.2005.03.024&rfr_id=info%3Asid%2Fgoogle
  
  class ContextObject    

    attr_accessor(:referent, :referringEntity, :requestor, :referrer, :serviceType, :resolver, :custom)
		attr_reader(:admin)
    @@defined_entities = {"rft"=>"referent", "rfr"=>"referrer", "rfe"=>"referring-entity", "req"=>"requestor", "svc"=>"service-type", "res"=>"resolver"}
    
    # Creates a new ContextObject object and initializes the ContextObjectEntities.
    
    def initialize()
      @referent = ReferentEntity.new()
      @referringEntity = ReferringEntity.new()
      @requestor = RequestorEntity.new()
      @referrer = ReferrerEntity.new()
      @serviceType = [ServiceTypeEntity.new()]
      @resolver = [ResolverEntity.new()]
      @custom = []
      @admin = {"ctx_ver"=>{"label"=>"version", "value"=>"Z39.88-2004"}, "ctx_tim"=>{"label"=>"timestamp", "value"=>DateTime.now().to_s}, "ctx_id"=>{"label"=>"identifier", "value"=>""}, "ctx_enc"=>{"label"=>"encoding", "value"=>"info:ofi/enc:UTF-8"}}    
    end

    def deep_copy
      cloned = ContextObject.new
      cloned.import_context_object( self )
      return cloned
    end
    
    # Serialize the ContextObject to XML.
    
    def xml      
      doc = REXML::Document.new()
      coContainer = doc.add_element "ctx:context-objects"
      coContainer.add_namespace("ctx","info:ofi/fmt:xml:xsd:ctx")
      coContainer.add_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")
      coContainer.add_attribute("xsi:schemaLocation", "info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx")
      co = coContainer.add_element "ctx:context-object"
      @admin.each_key do |k|
        co.add_attribute(@admin[k]["label"], @admin[k]["value"])
      end

      [@referent, @referringEntity, @requestor, @referrer].each do | ent |
        ent.xml(co) unless ent.empty?
      end
      
      [@serviceType, @resolver, @custom].each do |entCont|
        entCont.each do |ent|
          ent.xml(co) unless ent.empty?                      
        end
      end

      return doc.to_s
    end
    
    # Alias for .xml
    
    def sap2
      return xml
    end
    
    # Output the ContextObject as a Key-encoded value string.  Pass a boolean
    # true argument if you do not want the ctx_tim key included.
    
    def kev(no_date=false)
      require 'cgi'
      kevs = ["url_ver=Z39.88-2004"]
      
      # Loop through the administrative metadata      
      @admin.each_key do |k|
        next if k == "ctx_tim" && no_date                    
        kevs.push(k+"="+CGI.escape(@admin[k]["value"].to_s)) if @admin[k]["value"]                  
      end

      [@referent, @referringEntity, @requestor, @referrer].each do | ent |
        kevs.push(ent.kev) unless ent.empty?                  
      end
      
      [@serviceType, @resolver, @custom].each do |entCont|
        entCont.each do |ent|
          kevs.push(ent.kev) unless ent.empty?                      
        end
      end        
      return kevs.join("&")
    end
    
    # Outputs the ContextObject as a ruby hash.
    
    def to_hash
      co_hash = {"url_ver"=>"Z39.88-2004"}           
      
      @admin.each_key do |k|
        co_hash[k]=@admin[k]["value"] if @admin[k]["value"]
      end

      [@referent, @referringEntity, @requestor, @referrer].each do | ent |
        co_hash.merge!(ent.to_hash) unless ent.empty?
      end
      
      [@serviceType, @resolver, @custom].each do |entCont|
        entCont.each do |ent|
          co_hash.merge!(ent.to_hash) unless ent.empty?
        end
      end        
      return co_hash
    end    
    
    # Alias for .kev
    
    def sap1
      return kev
    end
    
    # Outputs a COinS (ContextObject in SPANS) span tag for the ContextObject.
    # Arguments are any other CSS classes you want included and the innerHTML 
    # content.
    
    def coins (classnames=nil, innerHTML=nil)      
      return "<span class='Z3988 #{classnames}' title='"+CGI.escapeHTML(self.kev(true))+"'>#{innerHTML}</span>"
    end
    
    # Adds another ServiceType entity to the context object and returns the 
    # array index of the new object.
    
    def add_service_type_entity
      @serviceType << ServiceTypeEntity.new
      return @serviceType.index(@serviceType.last)
    end

    # Adds another Resolver entity to the context object and returns the 
    # array index of the new object.
    
    def add_resolver_entity
      @resolver << ResolverEntity.new      
      return @resolver.index(@resolver.last)
    end  

    # Adds a custom entity to the ContextObject and returns array index of the 
    # new object.  Expects an abbreviation and label for KEV and XML output.
    
    def add_custom_entity(abbr=nil, label=nil)
      @custom << CustomEntity.new(abbr, label)      
      return @custom.index(@custom.last)
    end

    # Returns the appropriate CustomEntity for the given entity abbreviation.
    
    def custom_entity(abbr)
      return @custom.find { |c| c.abbr == abbr }
    end
    
    # Sets a ContextObject administration field.
    
    def set_administration_key(key, val)
      raise ArgumentException, "#{key} is not a valid admin key!" unless @admin.keys.index(key)
      @admin[key]["value"] = val
    end

    # Imports an existing Key-encoded value string and sets the appropriate 
    # entities.
    
    def import_kev(kev)      
      co = CGI::parse(kev)
      co2 = {}
      co.each_key do |k|
        # Only take the first value from the value array
      	co2[k] = co[k][0]
      end
      self.import_hash(co2)
    end
    
    # Initialize a new ContextObject object from an existing KEV
    
    def self.new_from_kev(kev)
      co = self.new
      co.import_kev(kev)
      return co
    end  
    
    # Imports an existing XML encoded context object and sets the appropriate
    # entities
    
    def import_xml(xml)			
			doc = REXML::Document.new xml
      # Cut to the context object
			ctx = REXML::XPath.first(doc, ".//ctx:context-object", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})
			ctx.attributes.each do |attr, val|				
				@admin.each do |adm, vals|
					self.set_administration_key(adm, val) if vals["label"] == attr											
				end
			end
			ctx.to_a.each do | ent |
				if @@defined_entities.value?(ent.name())
					var = @@defined_entities.keys[@@defined_entities.values.index(ent.name())]
					meth = "import_#{var}_node"
					self.send(meth, ent)
				else
					self.import_custom_node(ent)
				end
			end
    end
    
    # Initialize a new ContextObject object from an existing XML ContextObject
    
    def self.new_from_xml(xml)
      co = self.new
      co.import_xml(xml)
      return co
    end
    
    # Searches the Custom Entities for the key/value pair and returns an array
    # of the @custom array keys of any matches.
		
    def search_custom_entities(key, val)
      matches = []
      @custom.each do |cus|
        begin
          matches << @custom.index(cus) if cus.instance_variable_get('@'+key) == val                      
        rescue NameError
          next
        end
      end
      return matches
    end
    
    # Imports an existing hash of ContextObject values and sets the appropriate
    # entities.
    
    def import_hash(hash)            
      ref = {}
      openurl_keys = ["url_ver", "url_tim", "url_ctx_fmt"]
      hash.each do |key, val|
        if openurl_keys.include?(key)          
          next # None of these matter much for our purposes
        elsif @admin.has_key?(key)
          self.set_administration_key(key, val)
        elsif key.downcase.match(/^[a-z]{3}_val_fmt$/)
          # Realistically should only be rft or rfe:  get the format
          (entity, v, fmt) = key.split("_")
          ent = self.translate_abbr(entity)  
          eval("@"+ent).set_format(val)
        elsif key.match(/^[a-z]{3}_ref/)
          # determines if we have a by-reference context object
          (entity, v, fmt) = key.split("_")
          ent = self.translate_abbr(entity)
          # by-reference requires two fields, format and location, if this is
          # the first field we've run across, set a place holder until we get
          # the other value
          unless ref[entity]
            if fmt
              ref_key = "format"
            else 
              ref_key = "location"
            end
            ref[entity] = [ref_key, val]
          else
            if ref[entity][0] == "format"
              eval("@"+ent).set_reference(val, ref[entity][1])
            else
              eval("@"+ent).set_reference(ref[entity][1], val)
            end
          end
        elsif key.match(/^[a-z]{3}_id$/)
          # Get the entity identifier
          (entity, v) = key.split("_")
          ent = self.translate_abbr(entity)
          eval("@"+ent).set_identifier(val)      
        elsif key.match(/^[a-z]{3}_dat$/)
          # Get any private data
          (entity, v) = key.split("_")
          ent = self.translate_abbr(entity)
          eval("@"+ent).set_private_data(val)  
        else
          # collect the entity metadata
          keyparts = key.split(".")            
          if keyparts.length > 1
            # This is 1.0 OpenURL
            ent = self.translate_abbr(keyparts[0])
            eval("@"+ent).set_metadata(keyparts[1], val)
          else
            # This is a 0.1 OpenURL.  Your mileage may vary on how accurately
            # this maps.
            if key == 'id'
              @referent.set_identifier(val)
            elsif key == 'sid'
              @referrer.set_identifier("info:sid/"+val.to_s)            
            else 
              @referent.set_metadata(key, val)
            end
          end
        end
      end  
      
      # Initialize a new ContextObject object from an existing key/value hash
      
      def self.new_from_hash(hash)
        co = self.new
        co.import_hash(hash)
        return co
      end
      
      # if we don't have a referent format (most likely because we have a 0.1
      # OpenURL), try to determine something from the genre.  If that doesn't 
      # exist, just call it a journal since most 0.1 OpenURLs would be one,
      # anyway.
      unless @referent.format        
       fmt = case @referent.metadata['genre']
         when /article|journal|issue|proceeding|conference|preprint/ then 'journal'
         when /book|bookitem|report|document/ then 'book'
         else 'journal'
         end
       @referent.set_format(fmt)
      end
    end
    
    # Translates the abbreviated entity (rft, rfr, etc.) to the associated class
    # name.  For repeatable entities, uses the first object in the array.  Returns
    # a string of the object name which would then be eval'ed to call a method
    # upon.
    
    def translate_abbr(abbr)
      if @@defined_entities.has_key?abbr
        ent = @@defined_entities[abbr]
        if ent == "service-type"
          ent = "serviceType[0]"
        elsif ent == "resolver"
          ent = "resolver[0]"
        elsif ent == "referring-entity"      
          ent = "referringEntity"
        end
      else
        idx = self.search_custom_entities("abbr", abbr)
        if idx.length == 0
          self.add_custom_entity(abbr)
          idx = self.search_custom_entities("abbr", abbr)
        end
        ent = "custom["+idx[0].to_s+"]"
      end
      return ent
    end
    
    # Imports an existing OpenURL::ContextObject object and sets the appropriate
    # entity values.
    
    def import_context_object(context_object)
    	@admin.each_key { |k|
    		self.set_administration_key(k, context_object.admin[k]["value"])
    	}	
      [context_object.referent, context_object.referringEntity, context_object.requestor, context_object.referrer].each {| ent |
        unless ent.empty?
          ['identifier', 'format', 'private_data'].each { |var|
            unless ent.send(var).nil?
              unless ent.kind_of?(OpenURL::ReferringEntity)
                eval("@"+ent.label.downcase).send('set_'+var,ent.send(var))
              else
                @referringEntity.send('set_'+var,ent.send(var))
              end
            end
          }
          unless ent.reference["format"].nil? or ent.reference["format"].nil?
            unless ent.kind_of?(OpenURL::ReferringEntity)          
              eval("@"+ent.label.downcase).set_reference(ent.reference["location"], ent.reference["format"])
            else
              @referringEntity.set_referent(ent.reference["location"], ent.reference["format"])
            end
          end
          ent.metadata.each_key { |k|
            unless ent.metadata[k].nil?
              unless ent.kind_of?(OpenURL::ReferringEntity)          
                eval("@"+ent.label.downcase).set_metadata(k, ent.metadata[k])
              else
                @referringEntity.set_metadata(k, ent.metadata[k])
              end
            end
          }
        end
      }
      context_object.serviceType.each { |svc|
        if @serviceType[0].empty?
          @serviceType[0] = svc
        else
          idx = self.add_service_type_entity
          @serviceType[idx] = svc
        end
          
      }
      context_object.resolver.each { |res|
        if @resolver[0].empty?
          @resolver[0] = res
        else
          idx = self.add_resolver_entity
          @resolver[idx] = res
        end
          
      }
      context_object.custom.each { |cus|
        idx = self.add_custom_entity(cus.abbr, cus.label)
        @custom[idx] = cus
      }         
    end
    
    # Initialize a new ContextObject object from an existing 
    # OpenURL::ContextObject

    def self.new_from_context_object(context_object)
      co = self.new
      co.import_context_object(context_object)
      return co
    end       
    
    protected
        
    def import_rft_node(node)
			self.import_xml_common(@referent, node)	
			self.import_xml_mbv_ref(@referent, node)
    end
    
    def import_rfe_node(node)    	
			self.import_xml_common(@referringEntity, node)	    	
			self.import_xml_mbv_ref(@referringEntity, node)			
    end

    def import_rfr_node(node)
			self.import_xml_common(@referrer, node)	
			self.import_xml_mbv(@referrer, node)
    end
    
    def import_req_node(node)
			self.import_xml_common(@requestor, node)	    	
			self.import_xml_mbv(@requestor, node)			
    end
		
		def import_svc_node(node)
    	if @serviceType[0].empty?
    		key = 0
    	else
    		key = self.add_service_type_entity
    	end
			self.import_xml_common(@serviceType[key], node)				
			self.import_xml_mbv(@serviceType[key], node)			
		end
		
		def import_custom_node(node)
			key = self.add_custom_entity(node.name())
			self.import_xml_commom(@custom[key], node)
			self.import_xml_mbv(@custom[key], node)			
		end

    def import_res_node(node)
    	if @resolver[0].empty?
    		key = 0
    	else
    		key = self.add_resolver_entity
    	end
			self.import_xml_common(@resolver[key], node)	
			self.import_xml_mbv(@resolver[key], node)			
    end
    
    # Parses the data that should apply to all XML context objects
    
		def import_xml_common(ent, node) 
			fmt = REXML::XPath.first(node, ".//ctx:format", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})
			ent.set_format(fmt.get_text.value) if fmt and fmt.has_text

			id = REXML::XPath.first(node, ".//ctx:identifier", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})
			ent.set_identifier(id.get_text.value) if id and id.has_text?

			priv = REXML::XPath.first(node, ".//ctx:private-data", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})
			ent.set_private_data(priv.get_text.value) if priv and priv.has_text?

			ref = REXML::XPath.first(node, ".//ctx:metadata-by-ref", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})					
			if ref
				ref.to_a.each do |r|
					if r.name() == "format"
						format = r.get_text.value
					else 
						location = r.get_text.value
					end
					ent.set_reference(location, format)
				end
			end
		end
		
    # Parses metadata-by-val data
    
		def import_xml_mbv(ent, node)
			mbv = REXML::XPath.first(node, ".//ctx:metadata-by-val", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})
      
			if mbv        
				mbv.to_a.each { |m|
					ent.set_metadata(m.name(), m.get_text.value)
				}
			end			
		end
    
    # Referent and ReferringEntities place their metadata-by-val inside
    # the format element
    
		def import_xml_mbv_ref(ent, node)
			ns = "info:ofi/fmt:xml:xsd:"+ent.format
			mbv = REXML::XPath.first(node, ".//fmt:"+ent.format, {"fmt"=>ns})					
			if mbv
				mbv.to_a.each { |m|
          if m.has_text?
            ent.set_metadata(m.name(), m.get_text.value)            
          end
          if m.has_elements?
            m.to_a.each { | md |
              if md.has_text?
                ent.set_metadata(md.name(), md.get_text.value)
              end
            }
          end
				}
			end					
		end    
  end  
end
