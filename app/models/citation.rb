require 'crfparser'
require 'string_helpers'

class Citation < ActiveRecord::Base

  serialize :authors, Array
  serialize :contexts, Array

  def valid_citation?
    return true if authors.empty? && year
    return true if (location || booktitle) && year
    return true if title
    return false
  end

  def to_xml
    xml = "<citation valid=#{valid_citation?}>\n"
    if !authors.empty?
      xml << "<authors>\n"
      authors.each {|auth| xml << "<author>#{auth.xml_escape}</author>\n" }
      xml << "</authors>\n"
    end

    %w(title year journal booktitle tech volume pages editor
       publisher institution location note).each {|heading|

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

  def self.create_from_string(str)
    cp = CRFParser.new
    begin
      hsh = cp.parse_string(str)
      hsh.keys.reject {|k| Citation.column_names.include?(k)}.each {|k|
        hsh.delete k
      }
      puts hsh.keys.join("\n")
      Citation.create(hsh)
    rescue Exception => e
      raise "Could not create citation from string: #{str}\nFailed with error: #{e}\n#{e.backtrace.join("\n")}"
    end
  end

end

