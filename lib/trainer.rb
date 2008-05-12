
class Trainer

  Feature_file = "features.yaml"

  def load_features(force=false)
    if !@featset || force
      @featset = File.open(Feature_file) { |f| YAML::load(f) }
    end
  end

  def dump_training_data(*range)
    true_harvests = Harvest.find(:all).select { |rh| rh.is_truth? }

    train_on_ids = true_harvests[*range].map { |rh| rh.id }
    load_features
    @featset.each { |id, feat_seq|
      next unless train_on_ids.include?(id)
      write_training_data(feat_seq)
    } 
    return nil
  end

  def eval_harvests(*range)
    read_model
    true_harvests = Harvest.find(:all).select { |rh| rh.is_truth? }
    eval_on_ids = true_harvests[*range].map { |rh| rh.id }
    load_features
    @confusion = Hash.new{ |h1,k1| h1[k1] = Hash.new { |h, k| h[k] = Hash.new(0) }}
    @right = @wrong = 0

    @featset.each { |id, feat_seq|
      next unless eval_on_ids.include?(id)
      passes = 0
      passes += 1
      num_wrong = 0
      to_correct = nil

      classifications = eval(feat_seq)

      classifications.each_with_index { |c, i|
        type = feat_seq.get_feat(:ttype, i)
        truth = feat_seq.get_truth(i)
        clength = feat_seq.get_feat(:clength_wows, i)
        @confusion[type][truth][c] += clength
        is_correct = c == truth
        (is_correct) ? @right += 1 : @wrong += 1
        if !is_correct
          num_wrong += 1
        end
        #puts "Text: #{word_a[i].strip}; InEvent: #{truth}; Classified: #{c}" unless c == truth
      }

      puts "Done #{id}"
    }
    pp @confusion
    puts "Accuracy: #{@right / (@right+@wrong).to_f * 100}"
    return @confusion
  end

  def train(*range)
    dump_training_data(*range)
    describe_features
    out = learn
    out.display
  end
  
  attr_reader :featset
end


class TrainerCRF < Trainer
  Template_file = "template.crf"
  Train_file = "train.crf"
  Model_file = "model.crf"

  def initialize
    require "CRFPP"
  end

  def read_model
    @model = CRFPP::Tagger.new("-m #{Model_file}");
  end

  def eval(feat_seq)
    @model.clear
    line = nil
    num_lines = 0
    feat_seq.each_feat_vec { |feat_vec, truth|
      line = feat_vec.join(" ").strip
      #puts "#{num_lines}: #{line}"
      raise unless @model.add(line)
      num_lines += 1
    }
    raise unless @model.parse

    cs = []
    feat_seq.length.times { |i|
      c = (@model.y2(i) == "true")
      #puts "#{i}: #{c}"
      cs << c
    }
    cs
  end

  def dump_training_data(*range)
    File.open(Train_file, "w") { |@f|
      super(*range)
    }
  end

  def write_feat_seq(feat_seq)
    File.open(Train_file, "w") { |@f|
      write_training_data(feat_seq)
    }
  end

  def write_training_data(feat_seq)
    [false].each { |include_truth|
      feat_seq.each_feat_vec { |feat_vec, truth|
        @f << feat_vec.join(" ") << " " 
        @f << truth << "\n"
      }
      @f << "\n"
    }
  end

  def describe_features
    num_feats = @featset.num_feats
    File.open(Template_file, "w") { |f|
      num_feats.times { |i|
        f << "U#{i}:%x[0,#{i}]\n"
      }
    }
  end

  def learn
    IO.popen("crf_learn #{Template_file} #{Train_file} #{Model_file}") { |io|
      puts io.gets while !io.eof
    }
    
  end
end



class FeatureSet
  def initialize(file=nil)
    @sym_to_array = Hash.new { |h,k| h[k] = [] }
    @feat_names = []
    if file
=begin
      yaml = File.open(file) { |f| YAML::load(f) }
      return yaml
      debugger
      @feat_names = yaml[:feat_names]
      @hash = { }
      yaml[:hash].each_pair{ |id, seq_hash| 
        @hash[id] = FeatureSequence.new(self, seq_hash)
      }
      @hash.each_pair { |id, feat_seq|
        feat_seq.each_feat { |fname, fval|
          @sym_to_array[fname] << fval if Symbol === fval
        }
      }
=end
    else
      @hash = Hash.new {|h1, k1| h1[k1] = Hash.new {|h2, k2| h2[k2] = [] }}
    end
  end

  def new_feature_sequence(id)
    @hash[id] = FeatureSequence.new(self)
  end

  def to_yaml_properties
    ['@hash', '@sym_to_array', '@feat_names']
  end

  def write_to_file(file)
    find_syms
    File.open(file, "w") { |f| f << self.to_yaml }
  end

  def each(&block)
    @hash.each {|id, feat_seq| yield(id, feat_seq) }
  end

  def add_feat_name(name)
    @feat_names |= [name]
  end
  def num_feats
    @feat_names.length
  end
  def find_syms
    @hash.each_pair { |id, feat_seq|
      feat_seq.each_feat { |fname, fval|
        @sym_to_array[fname] |= [fval] if Symbol === fval
      }
    }
  end
  attr_reader :feat_names, :sym_to_array
end

class FeatureSequence
  def initialize(fs, seq_hash=nil)
    @featset = fs
    if seq_hash
      @truth = seq_hash[:truth]
      @feats = seq_hash[:feats]
    else
      @truth = []
      @feats = Hash.new { |h, k| h[k] = [] } 
    end
    @tokens = []
  end

  def to_yaml_properties
    [ '@truth', '@feats', '@featset' ]
  end

  def get_feat(feat, i)
    @feats[feat][i]
  end
  def get_truth(i)
    @truth[i]
  end

  def each_feat(&block)
    @feats.each_pair { |fn, fvec|
      fvec.each { |fval|
        yield(fn, fval)
      }
    }
  end

  def length
    @feats.values.first.length rescue 0
  end

  def each_feat_vec(&block)
    0.upto(length-1) { |i|
      yield(get_feat_vec(i), @truth[i])
    }
  end

  def get_feat_vec(i)
    feat_vec = []
    word = nil
    @feats.each_pair { |fn, f_array|
      val = f_array[i]
      if fn == :word
        word = val
        next
      end
      case val
      when TrueClass then v = 1
      when FalseClass then v = 0
      when "nil", NilClass then v = 0
      when Symbol
        if false
        v = Array.new(@featset.sym_to_array[fn].length) { 0 }
        idx = @featset.sym_to_array[fn].index(val)
        v[idx] = 1 if idx
        else
          v = val.to_s
          #debugger
        end
      when Fixnum, Float then v = val
      when String then v = val.to_i
      else raise "#{val}"
      end
      debugger unless v
      feat_vec << v
    }
    feat_vec.flatten!
    feat_vec.unshift(word) if word
    feat_vec
  end

  def process_tokens
    clusterer = HarvestManager::TokenClusterer.new
    @tokens.each { |token|
      debugger unless token
      clusterer.add_token(token)
    }
    clusterer.find_best_groups

    @tokens.each_with_index { |token, i|
      feat_hash = token_features(token)
      feat_hash.merge!(path_features(token.parent.my_path_str))
      
      #feat_hash.merge!(:truth => truth)
      #puts "#{percent_overlap}:  #{token.content}"
      feat_hash.merge!(path_analyzer_features(path_analyzer, token))
      feat_hash.each_pair { |fname, val| 
        @feats[fname][i] = val 
        @featset.add_feat_name(fname)
      }
    }
  end      

  def add_token(token, truth=nil)
    debugger unless token
    @tokens << token
    @truth << truth
  end

  def token_features(token)
    feats = {}
    word = token.content.strip.gsub(/\s/, "_").string[0,15]
    word = "_" if word.length == 0
    feats.merge!(
                 :word => word,
                 :ttype => token.type,
                 :clength => token.content.length,
                 :clength_wows => token.content.length_without_whitespace,
                 :t_start_offset => token.start_offset,
                 :t_num_parent_nodes => token.parent_nodes.length
                 )

    feats
  end

  def path_features(path)
    feats = {}
    tags = path.split('/')
    feats[:path_length] = tags.length # depth
    ["table", "div", "p", "td", "tr"].each { |element_name|
      some = tags.select { |t| t =~ /#{element_name}\[/i }
      len = some.length    
      feats["path_count_of_#{element_name}".to_sym] = len
      feats["path_pos_first_of_#{element_name}".to_sym] = 
        len > 0 ? some.first.scan(/\[(\d+)\]/)[0][0] : "nil"
      feats["path_pos_last_of_#{element_name}".to_sym] = 
        len > 0 ? some.last.scan(/\[(\d+)\]/)[0][0] : "nil"
    }
    feats
  end

  def clusterer_features(clusterer, token)
    feats = { }
    #feats[:clusterer_match] = 
    #  clusterer.path_match?(token)
    #feats[:clusterer_group_rank] =
    #  clusterer.group_rank(token)
    
    feats
  end
end
