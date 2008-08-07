module TokenFeatures

  QUOTES = Regexp.escape('"\'”’´‘“`')
  SEPARATORS = Regexp.escape(".;,)")

  def TokenFeatures.read_dict_file(filename)
    dict = {}
    f = File.open(filename, 'r')
    while l = f.gets
      l.strip!
      case l
        when /^\#\# Male/
          mode = 1
        when /^\#\# Female/
          mode = 2
        when /^\#\# Last/  
          mode = 4
        when /^\#\# Chinese/  
          mode = 4
        when /^\#\# Months/  
          mode = 8
        when /^\#\# Place/  
          mode = 16
        when /^\#\# Publisher/  
          mode = 32
        when (/^\#/) 
          # noop
        else 
          key = l
          val = 0
          # entry has a probability
          key, val = l.split(/\t/) if l =~ /\t/

          # some words in dict appear in multiple places
          unless dict[key] and dict[key] >= mode
            dict[key] ||= 0 
            dict[key] += mode
          end  
      end
    end
    f.close
    dict
  end

  DIR = File.dirname(__FILE__)
  DICT = TokenFeatures.read_dict_file("#{DIR}/resources/parsCitDict.txt")
  DICT_FLAGS = 
    {'publisherName' =>  32,
     'placeName'     =>  16,
     'monthName'     =>  8,
     'lastName'      =>  4,
     'femaleName'    =>  2,
     'maleName'      =>  1}

  private_class_method :read_dict_file

  def clear
    @possible_editor = nil
    @possible_chapter = nil
    @dict_status = nil
    @is_proceeding = nil
  end

  def last_char(toks, toksnp, tokslcnp, idx)
    case toks[idx][-1,1]
      when /[a-z]/
        'a'
      when /[A-Z]/
        'A'
      when /[0-9]/
        0
      else
        toks[idx][-1,1]
    end
  end

  def first_1_char(toks, toksnp, tokslcnp, idx); toks[idx][0,1]; end
  def first_2_chars(toks, toksnp, tokslcnp, idx); toks[idx][0,2]; end
  def first_3_chars(toks, toksnp, tokslcnp, idx); toks[idx][0,3]; end
  def first_4_chars(toks, toksnp, tokslcnp, idx); toks[idx][0,4]; end
  def first_5_chars(toks, toksnp, tokslcnp, idx); toks[idx][0,5]; end

  def last_1_char(toks, toksnp, tokslcnp, idx); toks[idx][-1,1]; end
  def last_2_chars(toks, toksnp, tokslcnp, idx); toks[idx][-2,2] || toks[idx]; end
  def last_3_chars(toks, toksnp, tokslcnp, idx); toks[idx][-3,3] || toks[idx]; end
  def last_4_chars(toks, toksnp, tokslcnp, idx); toks[idx][-4,4] || toks[idx]; end

  def toklcnp(toks, toksnp, tokslcnp, idx); tokslcnp[idx]; end

  def capitalization(toks, toksnp, tokslcnp, idx)
    case toksnp[idx]
      when /^[A-Z]$/
        "singleCap"
      when /^[A-Z][a-z]+/
        "InitCap"
      when /^[A-Z]+$/
        "AllCap"
      else
        "others"
    end
  end

  def numbers(toks, toksnp, tokslcnp, idx)
    (toks[idx]           =~ /[0-9]\-[0-9]/)          ? "possiblePage" :
      (toks[idx]         =~ /^\D*(19|20)[0-9][0-9]\D*$/)   ? "year"         :
      (toks[idx]         =~ /[0-9]\([0-9]+\)/)       ? "possibleVol"  :
      (toksnp[idx]       =~ /^(19|20)[0-9][0-9]$/)   ? "year"         :
      (toksnp[idx]       =~ /^[0-9]$/)               ? "1dig"         :
      (toksnp[idx]       =~ /^[0-9][0-9]$/)          ? "2dig"         :
      (toksnp[idx]       =~ /^[0-9][0-9][0-9]$/)     ? "3dig"         :
      (toksnp[idx]       =~ /^[0-9]+$/)              ? "4+dig"        :
      (toksnp[idx]       =~ /^[0-9]+(th|st|nd|rd)$/) ? "ordinal"      :
      (toksnp[idx]       =~ /[0-9]/)                 ? "hasDig"       : "nonNum"
  end

  def possible_editor(toks, toksnp, tokslcnp, idx)
    if @possible_editor
      @possible_editor
    else
      @possible_editor = 
        (tokslcnp.any? { |t|  %w(ed editor editors eds edited).include?(t)} ? 
          "possibleEditors" : "noEditors")
    end
  end

  # if there is possible editor entry and "IN" preceeded by punctuation
  # this citation may be a book chapter
  def possible_chapter(toks, toksnp, tokslcnp, idx)
    if @possible_chapter
      @possible_chapter
    else
      @possible_chapter = 
        ((possible_editor(toks, toksnp, tokslcnp, idx) and
        (toks.join(" ") =~ /[\.,;]\s*in[:\s]/i)) ?
          "possibleChapter" : "noChapter")
    end
  end

  def is_proceeding(toks, toksnp, tokslcnp, idx)
    if @is_proceeding
      @is_proceeding
    else
      @is_proceeding = 
        (tokslcnp.any? {|t| 
          %w( proc proceeding proceedings ).include?(t.strip)
        } ? 'isProc' : 'noProc')
    end
  end

  def is_in(toks, toksnp, tokslcnp, idx)
    ((idx > 0) and 
     (idx < (toks.length - 1)) and 
     (toksnp[idx+1] =~ /^[A-Z]/) and
     (tokslcnp[idx] == 'in') and
     (toks[idx-1] =~ /[#{SEPARATORS}#{QUOTES}]/))? "inBook" : "notInBook"
  end

  def is_et_al(toks, toksnp, tokslcnp, idx)
    a = false
    a = ((tokslcnp[idx-1] == 'et') and (tokslcnp[idx] == 'al')) if idx > 0
    return a if a

    if idx < toks.length - 1
      a = ((tokslcnp[idx] == 'et') and (tokslcnp[idx+1] == 'al')) 
    end

    return (a ? "isEtAl" : "noEtAl")
  end

  def location(toks, toksnp, tokslcnp, idx)
    r = ((idx.to_f / toks.length) * 10).round
  end  

  def punct(toks, toksnp, tokslcnp, idx)
    (toks[idx]   =~ /^[\"\'\`]/)                    ? "leadQuote"   :
      (toks[idx] =~ /[\"\'\`][^s]?$/)               ? "endQuote"    :
      (toks[idx] =~ /\-.*\-/)                       ? "multiHyphen" :
      (toks[idx] =~ /[\-\,\:\;]$/)                  ? "contPunct"   :
      (toks[idx] =~ /[\!\?\.\"\']$/)                ? "stopPunct"   :
      (toks[idx] =~ /^[\(\[\{\<].+[\)\]\}\>].?$/)   ? "braces"      :
      (toks[idx] =~ /^[0-9]{2,5}\([0-9]{2,5}\).?$/) ? "possibleVol" : "others"
  end

  def a_is_in_dict(toks, toksnp, tokslcnp, idx)
    ret = {}
    @dict_status = (DICT[tokslcnp[idx]] ? DICT[tokslcnp[idx]] : 0)
  end  

  def publisherName(toks, toksnp, tokslcnp, idx)
    (@dict_status & DICT_FLAGS['publisherName']) > 0 ? 'publisherName' : 'noPublisherName'
  end

  def placeName(toks, toksnp, tokslcnp, idx)
    (@dict_status & DICT_FLAGS['placeName']) > 0 ? 'placeName' : 'noPlaceName'
  end

  def monthName(toks, toksnp, tokslcnp, idx)
    (@dict_status & DICT_FLAGS['monthName']) > 0 ? 'monthName' : 'noMonthName'
  end

  def lastName(toks, toksnp, tokslcnp, idx)
    (@dict_status & DICT_FLAGS['lastName']) > 0 ? 'lastName' : 'noLastName'
  end 

  def femaleName(toks, toksnp, tokslcnp, idx)
    (@dict_status & DICT_FLAGS['femaleName']) > 0 ? 'femaleName' : 'noFemaleName'
  end 

  def maleName(toks, toksnp, tokslcnp, idx)
    (@dict_status & DICT_FLAGS['maleName']) > 0 ? 'maleName' : 'noMaleName'
  end 

end


