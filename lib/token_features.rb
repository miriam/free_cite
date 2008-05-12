module TokenFeatures

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
    @dict_status = nil
  end

  def last_char(toks, toknp, toklcnp, idx)
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

  def first_1_char(toks, toknp, toklcnp, idx); toks[idx][0,1]; end
  def first_2_chars(toks, toknp, toklcnp, idx); toks[idx][0,2]; end
  def first_3_chars(toks, toknp, toklcnp, idx); toks[idx][0,3]; end
  def first_4_chars(toks, toknp, toklcnp, idx); toks[idx][0,4]; end
  def first_5_chars(toks, toknp, toklcnp, idx); toks[idx][0,5]; end

  def last_1_char(toks, toknp, toklcnp, idx); toks[idx][-1,1]; end
  def last_2_chars(toks, toknp, toklcnp, idx); toks[idx][-2,2] || toks[idx]; end
  def last_3_chars(toks, toknp, toklcnp, idx); toks[idx][-3,3] || toks[idx]; end
  def last_4_chars(toks, toknp, toklcnp, idx); toks[idx][-4,4] || toks[idx]; end

  def toklcnp(toks, toknp, toklcnp, idx); toklcnp; end

  def capitalization(toks, toknp, toklcnp, idx)
    case toknp
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

  def numbers(toks, toknp, toklcnp, idx)
    (toknp         =~ /^(19|20)[0-9][0-9]$/)   ? "year"         :
      (toks[idx]   =~ /[0-9]\-[0-9]/)          ? "possiblePage" :
      (toks[idx]   =~ /[0-9]\([0-9]+\)/)       ? "possibleVol"  :
      (toknp       =~ /^[0-9]$/)               ? "1dig"         :
      (toknp       =~ /^[0-9][0-9]$/)          ? "2dig"         :
      (toknp       =~ /^[0-9][0-9][0-9]$/)     ? "3dig"         :
      (toknp       =~ /^[0-9]+$/)              ? "4+dig"        :
      (toknp       =~ /^[0-9]+(th|st|nd|rd)$/) ? "ordinal"      :
      (toknp       =~ /[0-9]/)                 ? "hasDig"       : "nonNum"
  end

  def possible_editor(toks, toknp, toklcnp, idx)
    if @possible_editor
      @possible_editor
    else
      @possible_editor = 
        ((toks.join(" ") =~ /(ed\.|editor|editors|eds\.)/) ? 
          "possibleEditors" : "noEditors")
    end
  end

  #FIXME: this is broken in parsCit, but not broken here. May want to break it
  # and re-try
  # In parseCit, the length of toks includes the tags
  def location(toks, toknp, toklcnp, idx)
    r = ((idx.to_f / toks.length) * 10).round
  end  

  def punct(toks, toknp, toklcnp, idx)
    (toks[idx]   =~ /^[\"\'\`]/)                    ? "leadQuote"   :
      (toks[idx] =~ /[\"\'\`][^s]?$/)               ? "endQuote"    :
      (toks[idx] =~ /\-.*\-/)                       ? "multiHyphen" :
      (toks[idx] =~ /[\-\,\:\;]$/)                  ? "contPunct"   :
      (toks[idx] =~ /[\!\?\.\"\']$/)                ? "stopPunct"   :
      (toks[idx] =~ /^[\(\[\{\<].+[\)\]\}\>].?$/)   ? "braces"      :
      (toks[idx] =~ /^[0-9]{2,5}\([0-9]{2,5}\).?$/) ? "possibleVol" : "others"
  end

  def a_is_in_dict(toks, toknp, toklcnp, idx)
    ret = {}
    @dict_status = DICT[toklcnp] ? DICT[toklcnp] : 0
  end  

  def publisherName(toks, toknp, toklcnp, idx)
    @dict_status & DICT_FLAGS['publisherName'] > 0 ? 'publisherName' : 'no'
  end

  def placeName(toks, toknp, toklcnp, idx)
    @dict_status & DICT_FLAGS['placeName'] > 0 ? 'placeName' : 'no'
  end

  def monthName(toks, toknp, toklcnp, idx)
    @dict_status & DICT_FLAGS['monthName'] > 0 ? 'monthName' : 'no'
  end

  def lastName(toks, toknp, toklcnp, idx)
    @dict_status & DICT_FLAGS['lastName'] > 0 ? 'lastName' : 'no'
  end 

  def femaleName(toks, toknp, toklcnp, idx)
    @dict_status & DICT_FLAGS['femaleName'] > 0 ? 'femaleName' : 'no'
  end 

  def maleName(toks, toknp, toklcnp, idx)
    @dict_status & DICT_FLAGS['maleName'] > 0 ? 'maleName' : 'no'
  end 

end


