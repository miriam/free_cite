module Preprocessor

  MARKER_TYPES = {
    :SQUARE       => '\\[.+?\\]',
    :PAREN        => '\\(.+?\\)',
    :NAKEDNUM     => '\\d+',
    :NAKEDNUMDOT  => '\\d+\\.',
  }
  
  
  ##
  # Removes lines that appear to be junk from the citation text.
  ##
  def normalizeCiteText(cite_text) 
    cite_text.split(/\n/).reject {|line|
      line =~ /^[\s\d]*$/
    }.join("\n")
  end  # normalizeCiteText
  
  ##
  # Controls the process by which citations are segmented,
  # based on the result of trying to guess the type of
  # citation marker used in the reference section.  Returns
  # a reference to a list of citation objects.
  ##
  def segmentCitations(cite_text) 
    marker_type = guess_marker_type(cite_text)
    unless marker_type == 'UNKNOWN'
      citations = split_unmarked_citations(cite_text)
    else
      citations = split_citations_by_marker(cite_text, marker_type)
    end
    return citations
  end  # segmentCitations

  ##
  # Segments citations that have explicit markers in the
  # reference section.  Whenever a new line starts with an
  # expression that matches what we'd expect of a marker,
  # a new citation is started.  Returns a reference to a
  # list of citation objects.
  ##
  def split_citations_by_marker(cite_text, marker_type=nil)
    citations = []
    current_citation = Citation.new
    current_citation_string = nil

    cite_text.split(/\n/).each {|line|
      if line =~ /^\s*(#{MARKER_TYPES{marker_type}})\s*(.*)$/
        marker, cite_string = $1, $2
        if current_citation_string
          current_citation.citation_string = current_citation_string
          citations << current_citation
          current_citation_string = nil
        end
        current_citation = Citation.new
        current_citation.marker_type = marker_type
        current_citation.marker = marker
        current_citation_string = cite_string
      else
        if current_citation_string =~ /\s\-$/
          current_citation_string.sub(/\-$/, '')
          current_citation_string << line
        else
          current_citation_string << " " << line
        end
      end
    }

    if current_citation && current_citation_string
      current_citation.string = current_citation_string
      citations << current_citation
    end
    citations
  end
  
  
  
end

