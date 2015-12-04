#coding:utf-8
require 'bundler/setup'
require 'extractcontent'
require 'active_record'
require 'benchmark'
require_relative './models/queue_crawl'
require_relative './models/queue_index'
require_relative './models/page'
require_relative './models/word'
require_relative './models/inverted_index'
require_relative './models/bayes_train_datum'
require_relative './lib/crawler/crawler'
require_relative './lib/indexer/indexer'
require_relative './lib/naive_bayes/naive_bayes'
require_relative './lib/word_extraction/word_extraction'

ActiveRecord::Base.logger = Logger.new("sql.log")
ActiveRecord::Base.establish_connection(
  "adapter" => "sqlite3",
  "database" => "conveyer.db"
)

def get_content line
  page = QueueIndex.find_by(url: line)
  puts page
  puts page.body
  content, title = ExtractContent.analyse(page.body)
  puts content
end

def test_bayes page_id
  page_id = page_id.to_i
  puts page_id
  bayes = NaiveBayes.new
  bayes.train
  words = Page.find_by(id: page_id).words
end

def relative_pages page_id
  page = Page.find_by(id: page_id)
  # p page.words.pluck(:name)
  word_extraction = WordExtraction.new
  pages = nil

  scores = word_extraction.tf_idf(page.words_id_tf, Page.count)
  rtime = Benchmark.realtime do
    pages = word_extraction.relative_pages(scores)
  end
  p pages[0..100]
  puts "relative: #{rtime}s"
end

while line = gets
  line.chomp!
  relative_pages line
end
