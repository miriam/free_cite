module Postprocessor

  def normalize_fields(citation_hsh)
    citation_hsh.keys.each {|key| self.send("normalize_#{key}", citation_hsh) }
    citation_hsh
  end

  def method_missing(m, args)
    # Call normalize on any fields that don't have their own normalization
    # method defined
    if m.to_s =~ /^normalize/
      m.to_s =~ /normalize_(.*)$/
      normalize($1, args) 
    end  
  end
  
  # default normalization function for all fields that do not have their
  # own normalization
  # Strip any leading and/or trailing punctuation
  def normalize(key, hsh)
    hsh[key].gsub!(/^[^A-Za-z0-9]+/, '')
    hsh[key].gsub!(/[^A-Za-z0-9]+$/, '')
    hsh
  end

  ##
  # Tries to split the author tokens into individual author names
  # and then normalizes these names individually.  Returns a
  # list of author names.
  ##
  def normalize_author(hsh)
    str = hsh['author']
    tokens = repair_and_tokenize_author_text(str)
    authors = []
    current_auth = []
    begin_auth = 1
    tokens.each {|tok|
      if tok =~ /^(&|and)$/i
        if !current_auth.empty?
          auth = normalize_author_name(current_auth)
          authors << auth
        end
        current_auth = []
        begin_auth = 1
        next
      end  
      if begin_auth > 0
        current_auth << tok
        begin_auth = 0
        next
      end
      if tok =~ /,$/
        current_auth << tok
        if !current_auth.empty?
          auth = normalize_author_name(current_auth)
          authors << auth
          current_auth = []
          begin_auth = 1
        end  
      else
        current_auth << tok
      end
    }
    if !current_auth.empty?
      auth = normalize_author_name(current_auth)
      authors << auth unless auth.strip == "-"
    end
    hsh['authors'] = authors
    hsh
  end

  def normalize_date(hsh)
    str = hsh['date']
    if str =~ /(\d{4})/
      year = $1.to_i
      current_year = Time.now.year
      if year <= current_year+3
        ret = year
        hsh['year'] = ret
      else
        ret = nil
      end  
    end  
    hsh['date'] = ret
    return hsh
  end

  def normalize_volume(hsh)
    # If there are two numbers, they are volume and number.
    # e.g. "23(2)", "Vol. 23, No. 3" etc...
    if hsh['volume'] =~ /\D*(\d+)\D+(\d+)/i
      hsh['volume'] = $1
      hsh['number'] = $2
    # Otherwise, just pull out a number and hope that it's the volume
    elsif hsh['volume'] =~ /(\d+)/
      hsh['volume'] = $1
    end
    return hsh
  end

  ##
  # Normalizes page fields into the form "start--end".  If the page
  # field does not appear to be in a standard form, does nothing.
  ##
  def normalize_pages(hsh)
    hsh['pages'] = 
      case hsh['pages']
        when  /(\d+)[^\d]+?(\d+)/
          "#{$1}--#{$2}"
        when  /(\d+)/
          $1
        else
          hsh['pages']
      end 
    hsh
  end

  def repair_and_tokenize_author_text(author_text)
    # Repair obvious parse errors and weird notations.
    author_text.sub!(/et\.? al\.?.*$/, '')
    # FIXME: maybe I'm mis-understanding Perl regular expressions, but
    # this pattern from ParseCit appears to do the Wrong Thing:
    # author_text.sub!(/^.*?[a-zA-Z][a-zA-Z]+\. /, '')
    author_text.gsub!(/\(.*?\)/, '')
    author_text.gsub!(/^.*?\)\.?/, '')
    author_text.gsub!(/\(.*?$/, '')
    author_text.gsub!(/\[.*?\]/, '')
    author_text.gsub!(/^.*?\]\.?/, '')
    author_text.gsub!(/\[.*?$/, '')
    author_text.gsub!(/;/, ',')
    author_text.gsub!(/,/, ', ')
    author_text.gsub!(/\:/, ' ')
    author_text.gsub!(/[\:\"\<\>\/\?\{\}\[\]\+\=\(\)\*\^\%\$\#\@\!\~\_]/, '')
    author_text = join_multi_word_names(author_text)

    orig_tokens = author_text.split(/\s+/)
    tokens = []
    last = false
    orig_tokens.each_with_index {|tok, i|
      if tok !~ /[A-Za-z&]/
        if i < orig_tokens.length/2
          tokens = []
          next
        else
          last = true
        end
      end
      if (tok =~ /^(jr|sr|ph\.?d|m\.?d|esq)\.?\,?$/i and
          tokens.last =~ /\,$/) or
          tok =~ /^[IVX][IVX]+\.?\,?$/

        next  
      end
      tokens << tok
      break if last
    }
    tokens
  end # repair_and_tokenize_author_text

  # Insert underscores to join name particles. i.e.
  # Jon de Groote ---> Jon de_Groote
  def join_multi_word_names(author_text)
    author_text.gsub(/\b((?:van|von|der|den|de|di|le|el))\s/si) {
      "#{$1}_"
    }
  end

  ##
  # Tries to normalize an individual author name into the form
  # "First Middle Last", without punctuation.
  ##
  def normalize_author_name(auth_toks)
    return '' if auth_toks.empty?
    str = auth_toks.join(" ")
    if str =~ /(.+),\s*(.+)/
      str = "#{$1} #{$2}"
    end  
    str.gsub!(/\.\-/, '-')
    str.gsub!(/[\,\.]/, ' ')
    str.gsub!(/  +/, ' ')
    str.strip!

    if (str =~ /^[^\s][^\s]+(\s+[^\s]|\s+[^\s]\-[^\s])+$/) 
      new_toks = str.split(/\s+/)
      new_order = new_toks[1...new_toks.length];
      new_order << new_toks[0]
      str = new_order.join(" ")
    end
    return str
  end

end

