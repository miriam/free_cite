require 'openurl'

module CitationToContextObject

  def CitationToContextObject.load_journal_abbrs
    f = File.open("#{DIR}/resources/journal_abbreviations.yml", 'r')
    YAML::load(f).map(&:strip).join("|")
  end  

  def CitationToContextObject.load_country_codes
    f = File.open("#{DIR}/resources/country_codes.yml", 'r')
    ret = {}
    YAML::load(f).each {|cc| ret[cc.strip] =  true }
    ret
  end

  DIR = File.dirname(__FILE__)
  JOURNAL_ABBRS = load_journal_abbrs
  COUNTRY_CODES = load_country_codes
  
  private_class_method :load_journal_abbrs
  private_class_method :load_country_codes

  # Try to build a ContextObject out of a citation
  # We try to build three possible types of ContextObjects:
  # - book
  # - journal
  # - patent
  # - dissertation
  def CitationToContextObject.to_context_obj(citation)
    ctx = nil
    # if the citation has a booktitle, parse it into a book
    if citation.booktitle 
      ctx = to_book(citation)
    # elsif the citation has a journal title, parse it into a journal
    elsif citation.journal
      ctx = to_journal(citation)
    # elsif the citation has tech data and no booktitle or journal title,
    # try to guess the format from tech
    elsif citation.tech
      # could be a dissertation...
      if citation.tech =~ /(p\.?h\.?d\.?)|(dissertation)/i
        ctx = to_dissertation(citation)
      # or a patent...
      elsif citation.tech =~ /patent/i
        ctx = to_patent(citation)
      end  
    end  
    unless ctx
      # can't figure out what kind of referent we have, so just make a blank 
      # ContextObject
      ctx = OpenURL::ContextObject.new
      ctx.referent.set_format 'unknown' 
    end  
    ctx
  end

  # according to the book metadata format here:
  # http://alcme.oclc.org/openurl/servlet/OAIHandler/extension?verb=GetMetadata&metadataPrefix=mtx&identifier=info:ofi/fmt:kev:mtx:patent
  def CitationToContextObject.to_patent(citation)
    ctx = OpenURL::ContextObject.new
    ctx.referent.set_format 'patent'
    set_metadata(ctx, 'inventor', citation.authors) 
    set_metadata(ctx, 'title', citation.title) 
    set_metadata(ctx, 'assignee', citation.institution) 
    set_metadata(ctx, 'pubdate', citation.year.to_s) 
    
    # try to get a patent number
    # e.g. "1 234 56" or "1-23-423" or "1.231.32" or "123324"
    citation.tech =~ /((\d[ -\.]*)+)/
    set_metadata(ctx, 'number', $1.strip) unless $1.blank?

    # try to get a country code
    citation.tech.split(/[^A-Za-z]+/).each {|tok|
      if COUNTRY_CODES[tok]
        set_metadata(ctx, 'cc', tok) 
        break
      end
    }
    return ctx
  end

  def CitationToContextObject.to_dissertation(citation)
    ctx = OpenURL::ContextObject.new
    ctx.referent.set_format 'dissertation'

    # only one author for dissertation metaformat
    # let's assume there's only one in our array, but join all entries
    # just in case
    au = citation.authors.join(" ")
    set_metadata(ctx, 'au', citation.authors.join(" ")) unless au.strip.empty?

    set_metadata(ctx, 'title', citation.title) 
    set_metadata(ctx, 'inst', citation.institution) 
    set_metadata(ctx, 'date', citation.year.to_s) 
    set_metadata(ctx, 'co', citation.location) 

    # try to guess the degree
    citation.tech =~ /(p\.?h\.?d)/i
    set_metadata(ctx, 'degree', $1) 

    return ctx
  end

  # according to the book metadata format here:
  # http://alcme.oclc.org/openurl/servlet/OAIHandler/extension?verb=GetMetadata&metadataPrefix=mtx&identifier=info:ofi/fmt:kev:mtx:journal
  def CitationToContextObject.to_journal(citation)
    ctx = OpenURL::ContextObject.new
    ctx.referent.set_format 'journal'
    set_metadata(ctx, 'atitle', citation.title) 

    # try to guess if this journal title is full or short
    # look for common journal abbreviations
    if " #{citation.journal} " =~ /[^A-Za-z]#{JOURNAL_ABBRS}[^A-Za-z]/i
      set_metadata(ctx, 'stitle', citation.journal)
    else 
      set_metadata(ctx, 'jtitle', citation.journal) 
    end  
    set_metadata(ctx, 'au', citation.authors) 
    set_metadata(ctx, 'corp', citation.institution) 
    set_metadata(ctx, 'date', citation.year.to_s) 
    set_metadata(ctx, 'quarter', citation.number) 
    set_metadata(ctx, 'volume', citation.volume) 
    
    # Try to break pages field into a start and end page
    if citation.pages =~ /^\D*(\d+)--(\d+)\D*$/
      set_metadata(ctx, 'spage', $1) 
      set_metadata(ctx, 'epage', $2)
    else
      set_metadata(ctx, 'pages', citation.pages) 
    end

    if citation.tech =~ /pre[ -]?print/i
      set_metadata(ctx, 'genre', 'preprint')
    elsif citation.title || citation.pages
      set_metadata(ctx, 'genre', 'article')
    elsif citation.number || citation.volume 
      set_metadata(ctx, 'genre', 'issue')
    elsif citation.booktitle =~ /(proceeding|conference|proc[\. ])/i 
      if citation.title || citation.pages
        set_metadata(ctx, 'genre', 'proceeding')
      else
        set_metadata(ctx, 'genre', 'conference')
      end
    else
      set_metadata(ctx, 'genre', 'journal')
    end
    return ctx
  end

  # according to the book metadata format here:
  # http://alcme.oclc.org/openurl/servlet/OAIHandler/extension?verb=GetMetadata&metadataPrefix=mtx&identifier=info:ofi/fmt:kev:mtx:book
  def CitationToContextObject.to_book(citation)
    ctx = OpenURL::ContextObject.new
    ctx.referent.set_format 'book'
    set_metadata(ctx, 'au', citation.authors) 
    set_metadata(ctx, 'btitle', citation.booktitle) 

    # Try to break pages field into a start and end page
    if citation.pages =~ /^\D*(\d+)--(\d+)\D*$/
      set_metadata(ctx, 'spage', $1)
      set_metadata(ctx, 'epage', $2)
    else
      set_metadata(ctx, 'pages', citation.pages)
    end

    set_metadata(ctx, 'atitle', citation.title) 
    set_metadata(ctx, 'pub', citation.publisher) 
    set_metadata(ctx, 'date', citation.year.to_s) 
    set_metadata(ctx, 'place', citation.location) 
    set_metadata(ctx, 'corp', citation.institution) 

    if citation.booktitle =~ /(proceeding|conference|proc[\. ])/i 
      if citation.title || citation.pages
        set_metadata(ctx, 'genre', 'proceeding')
      else
        set_metadata(ctx, 'genre', 'conference')
      end
    elsif citation.title || citation.pages
      set_metadata(ctx, 'genre', 'bookitem')
    else
      set_metadata(ctx, 'genre', 'book')
    end
    return ctx
  end

  def CitationToContextObject.set_metadata(ctx, name, value)
    ctx.referent.set_metadata(name, value) if value
  end

end

