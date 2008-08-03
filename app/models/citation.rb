# == Schema Information
# Schema version: 1
#
# Table name: citations
#
#  id          :integer       not null, primary key
#  raw_string  :text
#  authors     :text          default(--- [])
#  title       :text
#  year        :integer
#  publisher   :text
#  location    :text
#  booktitle   :text
#  journal     :text
#  pages       :text
#  volume      :text
#  number      :text
#  contexts    :text          default(--- [])
#  tech        :text
#  institution :text
#  editor      :text
#  note        :text
#  marker_type :string(255)
#  marker      :string(255)
#

require 'rexml/document'
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
    txt = to_xml.to_s
    txt.gsub!(/<([^>]*)\s+[^>]+\s*>/, '<\1>')
    txt.gsub!(/<\/[^>]*>/, "</span>")
    txt.gsub!(/<([^>^\/]*)>/, '<span class="\1">')
    txt.sub!(/<span class="raw_string">/, '<br><span class="raw_string">')
    txt.gsub!(/>/, '> ')
    txt
  end

  def to_xml(opt=nil)
    doc = REXML::Document.new
    ci = doc.add_element("citation")
    aus = ci.add_element("authors")
    authors.each {|a| 
      au = aus.add_element("author")
      au.text = a
    }
    ci.add_attribute("valid", valid_citation?)

    %w(title journal booktitle editor volume publisher institution location 
       number pages year tech note ).each {|heading|

      if value = self.attributes[heading]
        el = ci.add_element(heading)
        el.text = value.to_s
      end
    }

    if !contexts.empty?
      ctxs = ci.add_element("contexts")
      contexts.each {|ctx| 
        c = ctxs.add_element("context") 
        c.text = ctx
      }
    end

    if marker
      el = ci.add_element("marker")
      el.text = marker.to_s
    end

    el = ci.add_element("raw_string")
    el.text = raw_string

    doc
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

