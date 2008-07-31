require 'crfparser'

DIR = File.dirname(__FILE__)
TAGGED_REFERENCES = "#{DIR}/../../lib/resources/trainingdata/tagged_references.txt"
TRAINING_DATA = "#{DIR}/training_data.txt"
TESTING_DATA = "#{DIR}/testing_data.txt"
TRAINING_REFS = "#{DIR}/training_refs.txt"
TESTING_REFS = "#{DIR}/testing_refs.txt"
MODEL_FILE = "#{DIR}/model"
TEMPLATE_FILE = "#{DIR}/../../lib/resources/parsCit.template"
OUTPUT_FILE = "#{DIR}/output.txt"
ANALYSIS_FILE = "#{DIR}/analysis.csv"
REFS_PREFIX = "training_refs_"
DATA_PREFIX = "training_data_"
TAG = "model_test"

class ModelTest
  
  def initialize
    @crf = CRFParser.new
  end

  def version
    @version ||=  `cd #{RAILS_ROOT}; git show --pretty=oneline HEAD | head -1`.strip
  end

  def branch
    if @branch.nil?
      branch = `cd #{RAILS_ROOT}; git branch`
      branch =~ /\*\s+(\S+)/
      @branch = $1
    end
    @branch
  end

  def aggregate_tags
    branches = `git branch`.gsub(/\*/, '').strip.split(/\s+/)
    branches.each {|branch|
      `git checkout #{branch}`
      tags = `git tag -l #{TAG}\*`.strip.split(/\s+/)
    }
  end

  def run_test(commit=false, commit_message="evaluating model", tag_name='', k=10)

    cross_validate(k)
    accuracy = analyze(k)

    if commit and tag_name.strip.blank?
      raise "You must supply a tag name if you want to commit and tag this test"
    end  

    if commit
      str = "git add #{ANALYSIS_FILE} #{OUTPUT_FILE}"
      puts "Adding test files to index \n#{str}"
      `#{str}`

      str = "git commit --message '#{commit_message}' #{ANALYSIS_FILE} #{OUTPUT_FILE}" 
      puts "Committing files to source control \n#{str}"
      `#{str}`

      str = "git tag #{TAG}_#{tag_name}_#{accuracy}"
      puts "Tagging: \n#{str}"
      `#{str}`
    end
  end

  def cleanup
    to_remove = [TRAINING_DATA, TESTING_DATA, TRAINING_REFS, TESTING_REFS, 
      MODEL_FILE]
    `rm -f #{to_remove.join(" ")} #{DIR}/#{DATA_PREFIX}*txt #{DIR}/#{REFS_PREFIX}*txt`
  end

  def cross_validate(k=10)
    generate_data(k)
    # clear the output file
    f = File.open(OUTPUT_FILE, 'w')
    f.close
    k.times {|i|
      puts "Performing #{i+1}th iteration of #{k}-fold cross validation"
      # generate training refs
      f = File.open(TRAINING_REFS, 'w')
      f.close
      k.times {|j|
        next if j == i
        `cat #{DIR}/#{REFS_PREFIX}#{j}.txt >> #{TRAINING_REFS}`
      }
      puts "Training model"
      train
      `cat #{DIR}/#{DATA_PREFIX}#{i}.txt > #{TESTING_DATA}`
      puts "Testing model"
      test
    }
  end

  # testpct: percentage of tagged references to hold out for testing
  def generate_data(k=10)
    testpct = k/100.0
    files = []
    k.times {|i| files << File.open("#{DIR}/#{REFS_PREFIX}#{i}.txt", 'w') }
    f = File.open(TAGGED_REFERENCES, 'r')
    while l = f.gets
      files[((rand * k) % k).floor].write(l)
    end
    f.close
    files.each_with_index {|f, i| 
      f.flush
      f.close
      @crf.write_training_file("#{DIR}/#{REFS_PREFIX}#{i}.txt", 
                               "#{DIR}/#{DATA_PREFIX}#{i}.txt")
    }
  end
  
  def train
    @crf.train(TRAINING_REFS, TRAINING_DATA, MODEL_FILE, TEMPLATE_FILE)
  end
  
  def test
    str = "crf_test -m #{MODEL_FILE} #{TESTING_DATA} >> #{OUTPUT_FILE}"
    puts str
    `#{str}`
  end
  
  def analyze(k)
    # get the size of the corpus
    corpus_size = `wc #{TAGGED_REFERENCES}`.split.first

    # go through all training/testing data to get complete list of output tags
    labels = {}
    [TRAINING_DATA, TESTING_DATA].each {|fn|
      f = File.open(fn, 'r')
      while l = f.gets
        next if l.strip.blank?
        labels[l.strip.split.last] = true
      end
      f.close
    }
    labels = labels.keys.sort
    puts "got labels:\n#{labels.join("\n")}"

    # reopen and go through the files again
    # for each reference, populate a confusion matrix hash
    references = []
    testf = File.open(OUTPUT_FILE, 'r')
    ref = new_hash(labels)
    while testl = testf.gets
      if testl.strip.blank? 
        references << ref
        ref = new_hash(labels)
        next
      end
      w = testl.strip.split
      te = w[-1]
      tr = w[-2]
      puts "#{te} #{tr}"
      ref[tr][te] += 1
    end
    testf.close
  
    # print results to a file
    f = File.open(ANALYSIS_FILE, 'w')
    f.write "Results for model\n branch: #{branch}\n version: #{version}\n"
    f.write "Test run on:,#{Time.now}\n"
    f.write "K-fold x-validation:,#{k}\n"
    f.write "Corpus size:,#{corpus_size}\n\n"

    # aggregate results in total hash
    total = {}
    labels.each {|trl|
      labels.each {|tel|
          total[trl] ||= {}
          total[trl][tel] = references.map {|r| r[trl][tel]}.sum
      }
    }
   
    # print a confusion matrix
    f.write 'truth\test,'
    f.write labels.join(',')
    f.write "\n"
    # first, by counts
    labels.each {|trl|
      f.write "#{trl},"
      f.write( labels.map {|tel| total[trl][tel] }.join(',') )
      f.write "\n"
    }
    # then by percent
    labels.each {|trl|
      f.write "#{trl},"
      f.write labels.map{|tel| total[trl][tel]/total[trl].values.sum.to_f }.join(',')
      f.write "\n"
    }

    # precision and recal by label
    f.write "\n"
    f.write "Label,Precision,Recall,F-measure\n"
    labels.each {|trl|
      p = total[trl][trl].to_f / labels.map{|l| total[l][trl]}.sum
      r = total[trl][trl].to_f / total[trl].values.sum
      fs = (2*p*r)/(p+r)
      f.write "#{trl},#{p},#{r},#{fs}\n"
    }

    # get the average accuracy-per-reference
    perfect = 0
    avgs = references.map {|r|
      n = labels.map {|label| r[label][label] }.sum
      d = labels.map {|lab| r[lab].values.sum }.sum
      perfect += 1 if n == d
      n.to_f / d
    }
    f.write "\nAverage accuracy by reference:,#{avgs.mean}\n"
    f.write "STD of Average accuracy by reference:,#{avgs.stddev}\n"
  
    # number of perfectly parsed references
    f.write "Perfect parses:,#{perfect},#{perfect.to_f/references.length}\n"
  
    # Total accuracy
    n = labels.map {|lab| total[lab][lab]}.sum
    d = labels.map {|lab1| labels.map {|lab2| total[lab1][lab2]}.sum }.sum
    f.write "Accuracy:, #{n/d.to_f}\n"
 
    f.flush
    f.close

    return n/d.to_f
  end

  private
  def new_hash(labels)
    h = Hash.new
    labels.each {|lab1|
      h[lab1] = {}
      labels.each {|lab2|
        h[lab1][lab2] = 0
      }
    }  
    h
  end
end
