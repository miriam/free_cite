require 'crfparser.rb'

namespace :crfparser do
  desc 'train a CRF model for the citation parser'
  task :train_model do
    CRFParser.new.train
  end  
end  

