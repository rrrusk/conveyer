#coding:utf-8
require 'benchmark'
require 'active_record'
require 'sinatra'
require 'sinatra/reloader'
require 'haml'
require 'bundler/setup'
require 'extractcontent'
require 'uri'
require 'yaml'
require_relative '../models/queue_crawl'
require_relative '../models/queue_index'
require_relative '../models/page'
require_relative '../models/word'
require_relative '../models/inverted_index'
require_relative '../models/bayes_train_datum'
require_relative '../models/bayes_datum'
require_relative '../models/user'
require_relative '../models/user_tf'
require_relative '../models/user_page'
require_relative '../lib/crawler/crawler'
require_relative '../lib/indexer/indexer'
require_relative '../lib/naive_bayes/naive_bayes'
require_relative '../lib/word_extraction/word_extraction'
require_relative '../lib/user_operator'

# ActiveRecord::Base.logger = Logger.new("sql.log")
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: "conveyer.db",
  timeout: 20000
)

enable :sessions
set :session_secret, 'jo89jiwudsu'

get '/' do
  url = params[:url]
  if url
    word_extraction = WordExtraction.new
    @title, @relative_pages = word_extraction.relative_pages_url(url)
    page_info = {}
    page_ids = @relative_pages.map {|x| x[:id]}
    Page.where(id: page_ids).pluck(:id, :title, :url).each do |(id, title, url)|
      page_info[id] = {title: title, url: url}
    end
    @relative_pages.each do |page|
      page.merge!(page_info[page[:id]]) rescue next page
    end
  else
    @relative_pages = []
    @home = true
  end
  haml :index
end

get '/pages' do
  @relative_pages = Page.where(state: "correct").pluck(:id, :title, :url).map{|id, title, url| {id: id, title: title, url: url}}
  haml :index
end

get '/recommend' do
  user = User.find_by(name: session[:name], password: session[:password]) if session[:name] && session[:password]
  if user
    @relative_pages = user.user_pages.pluck(:page_id, :similarity).map{|(id,similarity)| {id: id, similarity: similarity}}
    page_ids = @relative_pages.map {|x| x[:id]}
    page_info = {}
    Page.where(id: page_ids).pluck(:id, :title, :url).each do |(id, title, url)|
      page_info[id] = {title: title, url: url}
    end
    @title = "user page"
    @relative_pages.map! do |page|
      page.merge(page_info[page[:id]]) rescue next page
    end
    if @relative_pages.empty?
      @relative_pages = Page.where(state: "correct").order(id: :desc)
        .pluck(:id, :title, :url)
        .map{|(id, title, url)| {id: id, title: title, url: url}}
    end
    haml :recommend
  else
    redirect '/login'
  end
end

get '/login' do
  if params[:name] && params[:password]
    user_operator = UserOperator.new
    result = user_operator.login(params[:name], params[:password])
    if result
      session[:name], session[:password] = params[:name], params[:password]
      redirect '/recommend'
    else
      @message = "ログインに失敗しました"
    end
  else
    @message = "ユーザー名とパスワードを入力してください"
  end
  haml :login
end

get '/register' do
  if params[:name] && params[:password]
    user_operator = UserOperator.new
    result = user_operator.register(params[:name], params[:password])
    if result
      session[:name], session[:password] = params[:name], params[:password]
      redirect '/'
    else
      @message = "そのユーザー名は使われています"
    end
  else
    @message = "ユーザー名とパスワードを入力してください"
  end
  haml :register
end

post '/read_page' do
  page_id = params[:page_id].to_i
  page = Page.find_by(id: page_id)
  user_operator = UserOperator.new
  user_operator.update_parameters(page.words_id_tf, 1)
  redirect '/'
end

get %r{^/(.*)\.js$} do
  coffee :"coffee/#{params[:captures].first}"
end

if ARGV[0] == "development"
  puts "development mode..."
  get '/bayes' do
    @pages = []
    naive_bayes = NaiveBayes.new
    naive_bayes.load

    Page.all.each do |x|
      if x.bayes_train_datum
        answer = x.bayes_train_datum.judge == 1 ? "true" : "false"
      else
        answer = "not"
      end
      @pages << {
        title: x[:title],
        page_id: x[:id],
        url: x[:url],
        judge: x.state,
        answer: answer
      }
    end
    @pages = @pages.sort_by{|x| x[:judge]}
    haml :bayes
  end

  get '/makenews' do
    user_operator = UserOperator.new
    user_operator.make_news
    haml '%div make'
  end

  get '/train' do
    naive_bayes = NaiveBayes.new
    puts "start train"
    naive_bayes.train
    puts "start save"
    naive_bayes.save
    haml '%div saved'
  end

  get '/page/:page_id' do |page_id|
    word_extraction = WordExtraction.new
    page = Page.find_by(id: page_id)
    scores = word_extraction.tf_idf(page.words_id_tf, Page.count)
    @page = {title: page.title, url: page.url}
    @scores = scores.to_a.sort_by {|x| x[1]}.reverse
    haml :page
  end

  post '/judge' do
    page_id = params[:page_id]
    judge = params[:judge].to_i
    page = Page.find_by(id: page_id)
    bayes_train_datum = BayesTrainDatum.find_or_initialize_by(page_id: page_id)
    bayes_train_datum.url = page.url
    bayes_train_datum.judge = judge
    bayes_train_datum.save
    redirect '/'
  end
end
