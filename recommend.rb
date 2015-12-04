#coding:utf-8
require 'active_record'
require 'bundler/setup'
require 'extractcontent'
require 'uri'
require 'yaml'
require_relative './models/queue_crawl'
require_relative './models/queue_index'
require_relative './models/page'
require_relative './models/word'
require_relative './models/inverted_index'
require_relative './models/bayes_train_datum'
require_relative './models/bayes_datum'
require_relative './models/user'
require_relative './models/user_tf'
require_relative './models/user_page'
require_relative './lib/crawler/crawler'
require_relative './lib/indexer/indexer'
require_relative './lib/naive_bayes/naive_bayes'
require_relative './lib/word_extraction/word_extraction'
require_relative './lib/user_operator'

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "conveyer.db",
  timeout: 20000
)

user_operator = UserOperator.new
user_operator.make_news
