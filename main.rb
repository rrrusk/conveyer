#coding:utf-8

#user
#ページを見るとtf値2:8くらいにして加算
#relative_pagesアルゴリズムで高速化
#urlからrelative_pages呼び出せるようにする
#develop mode追加
#初期時どうするか
require 'bundler/setup'
require 'extractcontent'
require 'active_record'
require 'benchmark'
require 'uri'
require 'yaml'
require_relative './models/queue_crawl'
require_relative './models/queue_index'
require_relative './models/page'
require_relative './models/word'
require_relative './models/inverted_index'
require_relative './models/bayes_train_datum'
require_relative './models/bayes_datum'
require_relative './lib/crawler/crawler'
require_relative './lib/indexer/indexer'
require_relative './lib/naive_bayes/naive_bayes'
require_relative './lib/word_extraction/word_extraction'

# ActiveRecord::Base.logger = Logger.new("sql.log")
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "conveyer.db",
  timeout: 300000
)
loop do
  crawler = Crawler.new
  crawler.rss("http://b.hatena.ne.jp/hotentry/it.rss")
  crawler.crawl
  indexer = Indexer.new
  indexer.exec
end
