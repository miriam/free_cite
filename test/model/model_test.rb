require 'crfparser'

DIR = File.dirname(__FILE__)
TAGGED_REFERENCES = "#{DIR}/../../lib/resources/trainingdata/tagged_references.txt"
TRAINING_DATA = "#{DIR}/training_data.txt"
TESTING_DATA = "#{DIR}/testing_data.txt"
TRAINING_REFS = "#{DIR}/training_refs.txt"
TESTING_REFS = "#{DIR}/testing_refs.txt"
MODEL_FILE = "#{DIR}/model"
TEMPLATE_FILE = "#{DIR}/template.txt"
OUTPUT_FILE = "#{DIR}/output.txt"
ANALYSIS_FILE = "#{DIR}/analysis.txt"
MODEL_BRANCH_INDEX = "#{DIR}/model_branch_index.txt"

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

  def run_test(commit=false, commit_message="evaluating model", description=nil, testpct=0.3)
    # Update the model_branch_index to include this branch
    if commit
      `echo "#{branch},#{version},#{description}" >> #{MODEL_BRANCH_INDEX}` 
    end

    puts "Generating testing and training data..."
    generate_data(testpct)
    puts "Training model..."
    train
    puts "Testing model..."
    test
    puts "Evaluating results..."
    analyze

    if commit
      str = "git add #{[TRAINING_DATA, TESTING_DATA, TRAINING_REFS, \
        TESTING_REFS, MODEL_FILE, TEMPLATE_FILE, OUTPUT_FILE,       \
        ANALYSIS_FILE, MODEL_BRANCH_INDEX].join(" ")}"

      puts "Adding test files to index \n#{str}"
      `#{str}`

      str = `git commit --message "#{commit_message}" #{[TRAINING_DATA, \
        TESTING_DATA, TRAINING_REFS, TESTING_REFS, MODEL_FILE,          \
        TEMPLATE_FILE, OUTPUT_FILE, ANALYSIS_FILE,                      \
        MODEL_BRANCH_INDEX].join(" ")}` 

      puts "Committing files to source control \n#{str}"
      `#{str}`
    end
  end

  def cleanup
    `rm -f #{[TRAINING_DATA, TESTING_DATA, TRAINING_REFS, TESTING_REFS, MODEL_FILE, \
      TEMPLATE_FILE, OUTPUT_FILE, ANALYSIS_FILE].join(" ")}`
  end

  # testpct: percentage of tagged references to hold out for testing
  def generate_data(testpct=0.3)
    f = File.open(TAGGED_REFERENCES, 'r')
    test = File.open(TESTING_REFS, 'w')
    train = File.open(TRAINING_REFS, 'w')
    while l = f.gets
      rand < testpct ? test.write(l) : train.write(l)
    end
    f.close
    test.flush; test.close
    train.flush; train.close
    @crf.write_training_file(TRAINING_REFS, TRAINING_DATA)
    @crf.write_training_file(TESTING_REFS, TESTING_DATA)
  end
  
  def train
    @crf.train(TRAINING_REFS, TRAINING_DATA, MODEL_FILE, TEMPLATE_FILE)
  end
  
  def test
    str = "crf_test -m #{MODEL_FILE} #{TESTING_DATA} > #{OUTPUT_FILE}"
    puts str
    `#{str}`
  end
  
  def analyze
    # get the number of training exaples
    training_num = `wc #{TRAINING_REFS}`.split.first
    testing_num = `wc #{TESTING_REFS}`.split.first

    # go through the files once to get all the labels
    testf = File.open(OUTPUT_FILE, 'r')
    truthf = File.open(TESTING_DATA, 'r')
    labels = {}
    while (testl = testf.gets) && (truthl = truthf.gets)
      next if testl.strip.blank? && truthl.strip.blank?
      labels[testl.strip.split.last] = true
      labels[truthl.strip.split.last] = true
    end
    labels = labels.keys.sort

    # reopen and go through the files again
    # for each reference, populate a confusion matrix hash
    references = []
    testf = File.open(OUTPUT_FILE, 'r')
    truthf = File.open(TESTING_DATA, 'r')
    ref = new_hash(labels)
    while (testl = testf.gets) && (truthl = truthf.gets)
      if testl.strip.blank? && truthl.strip.blank?
        references << ref
        ref = new_hash(labels)
        next
      end
      te = testl.strip.split.last
      tr = truthl.strip.split.last
      ref[tr][te] += 1
    end
    testf.close
    truthf.close
  
    # print results to a file
    f = File.open(ANALYSIS_FILE, 'w')
    f.write "Results for model\n branch: #{branch}\n version: #{version}\n"
    f.write "Test run on:,#{Time.now}\n"
    f.write "Trained on:,#{training_num}\n"
    f.write "Tested on:,#{testing_num}\n\n"

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
      puts "#{n} #{d}"
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

    references
 
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
