require 'postprocessor'
require 'token_features'
require 'CRFPP'
require 'tempfile'

class CRFParser


  attr_reader :feature_order
  attr_reader :token_features

  include TokenFeatures
  include Postprocessor

  DIR = File.dirname(__FILE__)
  TAGGED_REFERENCES = "#{DIR}/resources/trainingdata/tagged_references.txt"
  TRAINING_DATA = "#{DIR}/resources/trainingdata/training_data.txt"
  MODEL_FILE = "#{DIR}/resources/model"
  TEMPLATE_FILE = "#{DIR}/resources/parsCit.template"
  
  # Feature functions must be performed in alphabetical order, since
  # later functions may depend on earlier ones.
  # If you want to specify a specific output order, do so in a yaml file in
  # config. See ../config/parscit_features.yml as an example
  # You may also use this config file to specify a subset of features to use
  # Just be careful not to exclude any functions that included functions 
  # depend on
  def initialize(config_file="#{DIR}/../config/parscit_features.yml")
    if config_file
      f = File.open(config_file, 'r')
      hsh = YAML::load( f )
      @feature_order = hsh["feature_order"].map(&:to_sym) 
      @token_features = hsh["feature_order"].sort.map(&:to_sym) 
    else
      @token_features = (TokenFeatures.instance_methods).sort.map(&:to_sym)
      @token_features.delete :clear
      @feature_order = @token_features
    end  
  end

  def model
    @model || @model = CRFPP::Tagger.new("-m #{MODEL_FILE}");
  end

  def parse_string(str)
    features = str_2_features(str)
    tags = eval_crfpp(features)
    toks = str.scan(/\S*\s*/)
    ret = {}
    tags.each_with_index {|t, i|
      (ret[t] ||= '') << toks[i]
    }
    normalize_fields(ret)
    ret['raw_string'] = str
    ret
  end

  def eval_command(feat_seq)
    fout = Tempfile.new("crfout", "#{DIR}/../tmp")
    feat_seq.each {|l| fout.write "#{l.join(" ")}\n"}
    fout.flush
    fout.close false
    fin = Tempfile.new("crfin", "#{DIR}/../tmp")
    fin.close false
    `crf_test -m #{MODEL_FILE} #{fout.path} > #{fin.path}`

    ret = []
    fin.open
    while l = fin.gets
      r = l.strip.split.last
      ret << r if r
    end
    fin.close true
    fout.close true
    ret
  end

  def eval_crfpp(feat_seq)
    model.clear
    num_lines = 0
    feat_seq.each {|vec|
      line = vec.join(" ").strip
      raise unless model.add(line)
      num_lines += 1
    }
    raise unless model.parse
    tags = []
    feat_seq.length.times {|i|
      tags << model.y2(i)
    }
    tags
  end

  def str_2_features(cstr, training=false)
    cstr.strip!
    features = []

    # calculate features on the full citation string

    # split the string on whitespace and calculate features on each token
    tokens_and_tags = cstr.split(/\s+/)
    tag = nil
    self.clear

    if training
      tokens = tokens_and_tags.reject {|t| t =~ /^<[\/]{0,1}([a-z]+)>$/}
    else  
      # if this is a testing run, disregard anything that looks like a tag
      tokens = tokens_and_tags unless training
    end

    toki = 0
    tokens_and_tags.each_with_index {|tok, i|
      # if this is training data, grab the mark-up tag and then skip it
      if training
        if tok =~ /^<([a-z]+)>$/ 
          tag = $1
          next
        elsif tok =~ /^<\/([a-z]+)>$/ 
          tok = nil
          raise TrainingError, "Mark-up tag mismatch #{tag} != #{$1}" if $1 != tag
          next
        end
      end
      feats = {}

      # strip token of any punctuation
      toknp = tok.gsub(/[^\w]/, '')
      toknp = "EMPTY" if toknp.blank?
      # downcase the stripped token
      toklcnp = (toknp == "EMPTY" ? "EMPTY" : toknp.downcase)

      # If we are training, there should always be a tag defined
      if training && tok.nil?
        raise TrainingError, "Incorrect mark-up:\n #{cstr}" 
      end  
      @token_features.each {|f| 
        feats[f] = self.send(f, tokens, toknp, toklcnp, toki) 
      }
      toki += 1

      features << [tok]
      @feature_order.each {|f| features.last << feats[f]}
      features.last << tag if training
    }
    return features
  end

  def write_training_file(tagged_refs=TAGGED_REFERENCES, 
    training_data=TRAINING_DATA)

    fin = File.open(tagged_refs, 'r')
    fout = File.open(training_data, 'w')
    while l = fin.gets
      data = str_2_features(l.strip, true)
      data.each {|line| fout.write("#{line.join(" ")}\n") }
      fout.write("\n")
    end

    fin.close
    fout.flush
    fout.close
  end

  def train(tagged_refs=TAGGED_REFERENCES, training_data=TRAINING_DATA, 
    model=MODEL_FILE, template=TEMPLATE_FILE)

    write_training_file(tagged_refs, training_data)
    `crf_learn #{TEMPLATE_FILE} #{TRAINING_DATA} #{MODEL_FILE}`
  end

end

class TrainingError < Exception; end



