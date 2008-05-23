require 'crfparser'
require 'string_helpers'
require 'openurl'
require 'postprocessor'
require 'citation_to_context_object'

class Citation < ActiveRecord::Base

  serialize :authors, Array
  serialize :contexts, Array

  def valid_citation?
    return true if authors.empty? && year
    return true if (location || booktitle) && year
    return true if title
    return false
  end

  def context_object
    @context_object ||= CitationToContextObject.to_context_obj(self)
  end

  def to_spans
    txt = to_xml
    txt.gsub!(/<([^\/>]*)( [^>]*)?>/, '<span class="\1" title="\1">')
    txt.gsub!(/<\/.*>/, '</span>')
    txt.sub!(/<span class="raw_string"/, '<br><span class="raw_string"')
    txt
  end

  def to_context_object
    return citation_to_context_obj(self)
  end

  def to_xml(opt=nil)
    xml = "<citation valid=#{valid_citation?}>\n"
    if !authors.empty?
      xml << "<authors>\n"
      authors.each {|auth| xml << "<author>#{auth.xml_escape}</author>\n" }
      xml << "</authors>\n"
    end

    %w(title journal booktitle editor volume publisher institution location 
       number pages year tech note ).each {|heading|

      if value = self.attributes[heading]
        xml << "<#{heading}>#{value.to_s.xml_escape}</#{heading}>\n"
      end
    }

    if !contexts.empty?
      xml << "<contexts>\n"
      contexts.each {|ctx| xml << "<context>#{ctx.xml_escape}</context>\n" }
      xml << "</contexts>\n"
    end

    if marker
      xml << "<marker>#{marker.xml_escape}</marker>\n"
    end

    if raw_string
      xml << "<raw_string>#{raw_string.xml_escape}</raw_string>\n"
    end
    xml << "</citation>\n"
    xml
  end

  def self.create_from_hash(hsh)
    hsh.keys.reject {|k| Citation.column_names.include?(k)}.each {|k|
      hsh.delete k
    }
    Citation.create(hsh)
  rescue Exception => e
    raise "Could not create citation from string: #{str}\nFailed with error: #{e}\n#{e.backtrace.join("\n")}"
  end

  def self.create_from_string(str)
    cp = CRFParser.new
    hsh = cp.parse_string(str)
    Citation.create_from_hash(hsh)
  end

end

