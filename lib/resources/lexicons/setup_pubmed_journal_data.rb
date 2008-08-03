#!/usr/bin/ruby

require 'yaml'


# journal files taken from:
# ftp://ftp.ncbi.nih.gov/pubmed/J_Medline.gz
# ftp://ftp.ncbi.nih.gov/pubmed/J_Sequence.gz
# ftp://ftp.ncbi.nih.gov/pubmed/J_Entrez.gz

DIR = File.dirname(__FILE__)

long = []
short = []
%w( J_Medline J_Sequence J_Entrez ).each {|fn|
  f = File.open("#{DIR}/#{fn}", 'r')
  while line = f.gets
    case line
      when /^MedAbbr:\s*(.*)$/
        short << $1
      when /^JournalTitle:\s*(.*)$/
        long << $1
    end  
  end
  f.close
}

f_short = File.open("#{DIR}/short_pubmed_journal_names.yml", 'w')
f_long = File.open("#{DIR}/long_pubmed_journal_names.yml", 'w')
f_short.write short.sort.uniq.to_yaml
f_long.write long.sort.uniq.to_yaml
f_short.flush
f_short.close
f_long.flush
f_long.close


