require File.dirname(__FILE__) + '/../test_helper'
require File.dirname(__FILE__) + '/../../lib/token_features'
require 'crfparser'
require 'unit_record'

ActiveRecord::Base.disconnect!

class TokenFeaturesTest < Test::Unit::TestCase

  def setup
    @crfparser = CRFParser.new(false)
    @ref = " W. H. Enright.   Improving the efficiency of matrix operations in the numerical solution of stiff ordinary differential equations.   ACM Trans. Math. Softw.,   4(2),   127-136,   June 1978. " 
    @tokens_and_tags, @tokens, @tokensnp, @tokenslcnp = 
      @crfparser.prepare_token_data(@ref.strip)
  end  

  def test_features
    @crfparser.token_features.each {|f|
      @tokens.each_with_index {|tok, i|
        self.send("tok_test_#{f}", f, @tokens, @tokensnp, @tokenslcnp, i)
      }
    }
  end

  def test_last_char
    pairs = [[['woefij'], 'a'],
     [['weofiw234809*&^*oeA'], 'A'],
     [['D'], 'A'],
     [['Da'], 'a'],
     [['1t'], 'a'],
     [['t'], 'a'],
     [['*'], '*'],
     [['!@#$%^&*('], '('],
     [['t1'], 0],
     [['1'], 0]]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.last_char(a, a, a, 0))
     }
  end

  def test_first_1_char
    pairs = [[['woefij'], 'w'],
     [['weofiw234809*&^*oeA'], 'w'],
     [['D'], 'D'],
     [['Da'], 'D'],
     [['1t'], '1'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '!'],
     [['t1'], 't'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.first_1_char(a, a, a, 0))
     }
  end

  def test_first_2_chars
    pairs = [[['woefij'], 'wo'],
     [['weofiw234809*&^*oeA'], 'we'],
     [['D'], 'D'],
     [['Da'], 'Da'],
     [['1t'], '1t'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '!@'],
     [['t1'], 't1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.first_2_chars(a, a, a, 0))
     }
  end

  def test_first_3_chars
    pairs = [[['woefij'], 'woe'],
     [['weofiw234809*&^*oeA'], 'weo'],
     [['D'], 'D'],
     [['Da'], 'Da'],
     [['1t'], '1t'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '!@#'],
     [['t1'], 't1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.first_3_chars(a, a, a, 0))
     }
  end

  def test_first_4_chars
    pairs = [[['woefij'], 'woef'],
     [['weofiw234809*&^*oeA'], 'weof'],
     [['D'], 'D'],
     [['Da'], 'Da'],
     [['Dax0'], 'Dax0'],
     [['1t'], '1t'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '!@#$'],
     [['t1'], 't1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.first_4_chars(a, a, a, 0))
     }
  end

  def test_first_5_chars
    pairs = [[['woefij'], 'woefi'],
     [['weofiw234809*&^*oeA'], 'weofi'],
     [['D'], 'D'],
     [['DadaX'], 'DadaX'],
     [['Da'], 'Da'],
     [['Dax0'], 'Dax0'],
     [['1t'], '1t'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '!@#$%'],
     [['t1'], 't1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.first_5_chars(a, a, a, 0))
     }
  end

  def last_1_char
    pairs = [[['woefij'], 'j'],
     [['weofiw234809*&^*oeA'], 'A'],
     [['D'], 'D'],
     [['DadaX'], 'X'],
     [['Da'], 'a'],
     [['Dax0'], '0'],
     [['1t'], 't'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '('],
     [['t1'], '1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.last_1_char(a, a, a, 0))
     }
  end

  def last_2_chars
    pairs = [[['woefij'], 'ij'],
     [['weofiw234809*&^*oeA'], 'eA'],
     [['D'], 'D'],
     [['DadaX'], 'aX'],
     [['Da'], 'Da'],
     [['Dax0'], 'x0'],
     [['1t'], '1t'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '*('],
     [['t1'], 't1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.last_2_char(a, a, a, 0))
     }
  end

  def last_3_chars
    pairs = [[['woefij'], 'fij'],
     [['weofiw234809*&^*oeA'], 'oeA'],
     [['D'], 'D'],
     [['DadaX'], 'daX'],
     [['Da'], 'Da'],
     [['Dax0'], 'ax0'],
     [['1t'], '1t'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '&*('],
     [['t1'], 't1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.last_3_char(a, a, a, 0))
     }
  end

  def last_4_chars
    pairs = [[['woefij'], 'efij'],
     [['weofiw234809*&^*oeA'], '*oeA'],
     [['D'], 'D'],
     [['DadaX'], 'adaX'],
     [['Da'], 'Da'],
     [['Dax0'], 'Dax0'],
     [['1t'], '1t'],
     [['t'], 't'],
     [['*'], '*'],
     [['!@#$%^&*('], '^&*('],
     [['t1'], 't1'],
     [['1'], '1']]

     pairs.each {|a, b|
       assert_equal(b, @crfparser.last_4_char(a, a, a, 0))
     }
  end

  def test_capitalization
    pairs = [[["W"], 'singleCap'],
     [["Enright"], 'InitCap'],
     [["IMPROVING"], 'AllCap'],
     [["ThE234"], 'InitCap'],
     [["efficiency"], 'others'],
     [["1978"], 'others']]
     pairs.each {|a, b|
       assert_equal(b, @crfparser.capitalization(a, a, a, 0))
     }
  end

  def test_numbers
    pairs = 
      [[['12-34'], 'possiblePage'],
       [['19-99'], 'possiblePage'],
       [['19(99):'], 'possibleVol'],
       [['19(99)'], 'possibleVol'],
       [['(8999)'], '4+dig'],
       [['(1999)'], 'year'],
       [['(2999)23094'], '4+dig'],
       [['wer(299923094'], 'hasDig'],
       [['2304$%^&89ddd=)'], 'hasDig'],
       [['2304$%^&89=)'], '4+dig'],
       [['3$%^&'], '1dig'],
       [['3st'], 'ordinal'],
       [['3rd'], 'ordinal'],
       [['989u83rd'], 'hasDig'],
       [['.2.5'], '2dig'],
       [['1.2.5'], '3dig'],
       [['(1999a)'], 'year'],
       [['a1a'], 'hasDig'],
       [['awef20.09woeifj'], 'hasDig'],
       [['awef2009woeifj'], 'year']]

    pairs.each {|a, b|
      s = [@crfparser.strip_punct(a.first)]
      puts "orig: #{a.first} tokenized: #{s} output: #{b}"
      assert_equal(b, @crfparser.numbers(a, s, s, 0))
    }
  end

  def test_possible_editor
    ee = %w(ed editor editors eds edited)
    ee.each {|e|
      @crfparser.clear
      assert_equal("possibleEditors", @crfparser.possible_editor([e], [e], [e], 0))
    }

    @crfparser.possible_editor([ee], [ee], [ee], 0)
    e = @crfparser.possible_editor(["foo"], ["foo"], ["foo"], 0)
    assert_equal("possibleEditors", e)

    @crfparser.clear
    ee = %w(foo bar 123SFOIEJ EDITUR)
    assert_equal("noEditors", @crfparser.possible_editor(ee, ee, ee, 0))
  end

  def test_possible_chapter
    
    refs = ['Flajolet, P., Gourdon, X., and Panario, D.   Random polynomials and polynomial factorization.   In Automata, Languages, and Programming   (1996),   F. Meyer auf der Heide and B. Monien, Eds.,   vol. 1099,   of Lecture Notes in Computer Science,   Springer-Verlag,   pp. 232-243.   Proceedings of the 23rd ICALP Conference, Paderborn,   July 1996.', 
    'JA Anderson (1977). Neural models with cognitive implications. In: D. LaBerge and S.J. Samuels (Eds .), Basic Processes in Reading: Perception and Comprehension . Hillsdale, New Jersey: Erlbaum Associates.',
    'Morgan, J.R. and Yarmush M.L. Gene Therapy in Tissue Engineering. In "Frontiers in Tissue Engineering", Patrick, Jr., CW, Mikos, AG, McIntire, LV, (eds.) Pergamon; Elsevier Science Publishers, Amsterdam, The Netherlands 1998; Chapter II.15 278- 310.',
    'Morgan, J.R. "Genetic Engineering of Skin Substitutes" In, Bioengineering of Skin Substitutes, International Business Communications, Inc., Southborough, MA 1998; Chapter 1.4., 61-73',
    'Sheridan, R.L., Morgan, J.R. and Mohammed, R. Biomaterials in Burn and Wound Dressings. In “Polymeric Biomaterials, Second Edition, Revised and Expanded”, Dumitriu (Ed) Marcel Dekker Inc. New York, 2001: Chapter 17; 451-458.']

    not_refs = ['Morse, D. H. 2006. Predator upon a flower. In final revision, scheduled for publication in Fall 2006 or Winter 2007. Harvard University Press. (ca. 400 pp.).',
    'Goldstein J, Perello M, and Nillni EA . 2005. PreproThyrotropin-Releasing Hormone178-199 Affects Tyrosine Hydroxylase Biosynthesis in Hypothalamic Neurons: a Possible Role for Pituitary Prolactin Regulation . In press Journal of Molecular Neuroscience 2006.',
    'Mulcahy LR, and Nillni EA. 2007 . Invited Review. The role of prohormone processing in the physiology of energy balance. Frontiers in Bioscience.'



    ]
  end

  private

  def tok_test_toklcnp(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert_equal(tokslcnp[idx], a)
  end

  def tok_test_placeName(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['noPlaceName', 'placeName'].include?(a))
  end

  def tok_test_last_1_char(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 1
      assert_equal(toks[idx], a)
    else
      assert_equal(1, a.length)
    end
    assert(toks[idx].end_with?(a))
  end

  def tok_test_is_et_al(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(["isEtAl", "noEtAl"].include?(a))
  end

  def tok_test_first_2_chars(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 2
      assert_equal(toks[idx], a)
    else
      assert_equal(2, a.length)
    end
    assert(toks[idx].start_with?(a))
  end

  def tok_test_possible_editor(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(["possibleEditors", "noEditors"].include?(a))
  end

  def tok_test_location(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert_equal(Fixnum, a.class)
    assert(a >= 0)
    assert(a <= 10)
  end

  def tok_test_in_book(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['inBook', 'notInBook'].include?(a))
  end

  def tok_test_femaleName(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['noFemaleName', 'femaleName'].include?(a))
  end

  def tok_test_last_char(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(String, a.class)
    assert(a.length, 1)
    assert(a == 'a' || a == 'A' || a == 0 || toks[idx].end_with?(a))
  end

  def tok_test_last_4_chars(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 4
      assert_equal(toks[idx], a)
    else
      assert_equal(4, a.length)
    end
    assert(toks[idx].end_with?(a))
  end

  def tok_test_publisherName(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['noPublisherName', 'publisherName'].include?(a))
  end

  def tok_test_first_5_chars(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 5
      assert_equal(toks[idx], a)
    else
      assert_equal(5, a.length)
    end
    assert(toks[idx].start_with?(a))
  end

  def tok_test_is_in(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(["inBook", "notInBook"].include?(a))
  end

  def tok_test_first_1_char(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 1
      assert_equal(toks[idx], a)
    else
      assert_equal(1, a.length)
    end
  end

  def tok_test_numbers(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    b = ["year", "possiblePage", "possibleVol", "1dig", "2dig", "3dig", 
      "4+dig", "ordinal", "hasDig", "nonNum"].include?(a)
    assert(b)  
  end

  def tok_test_lastName(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['noLastName', 'lastName'].include?(a))
  end

  def tok_test_last_3_chars(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 3
      assert_equal(toks[idx], a)
    else
      assert_equal(3, a.length)
    end
    assert(toks[idx].end_with?(a))
  end

  def tok_test_a_is_in_dict(f, toks, toksnp, tokslcnp, idx)
    n = nil
    assert_nothing_raised{n = @crfparser.send(f, toks, toksnp, tokslcnp, idx).class}
    assert_equal(Fixnum, n)
  end

  def tok_test_first_4_chars(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 4
      assert_equal(toks[idx], a)
    else
      assert_equal(4, a.length)
    end
    assert(toks[idx].start_with?(a))
  end

  def tok_test_is_proceeding(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['isProc', 'noProc'].include?(a))
  end

  def tok_test_capitalization(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(["singleCap", "InitCap", "AllCap", "others"].include?(a))
  end

  def tok_test_monthName(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['noMonthName', 'monthName'].include?(a))
  end

  def tok_test_last_2_chars(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 2
      assert_equal(toks[idx], a)
    else
      assert_equal(2, a.length)
    end
    assert(toks[idx].end_with?(a))
  end

  def tok_test_punct(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    b = %w(leadQuote endQuote multiHyphen contPunct stopPunct 
      braces possibleVol others).include?(a)
    assert(b)
  end

  def tok_test_first_3_chars(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    if toks[idx].length <= 3
      assert_equal(toks[idx], a)
    else
      assert_equal(3, a.length)
    end
    assert(toks[idx].start_with?(a))
  end

  def tok_test_possible_chapter(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['possibleChapter', 'noChapter'].include?(a))
  end

  def tok_test_maleName(f, toks, toksnp, tokslcnp, idx)
    a = nil
    assert_nothing_raised{a = @crfparser.send(f, toks, toksnp, tokslcnp, idx)}
    assert(['noMaleName', 'maleName'].include?(a))
  end

end

