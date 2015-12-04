include Math
require 'set'

class NaiveBayes
  attr_reader :vocabularies, :word_count, :category_count
  def initialize
    @vocabularies = Set.new
    @word_count = {}
    @category_count = {}
  end

  #教師データ更新
  def update_train_data url, judge
    page_id = Page.find_by(url: url).id
    bayes_train_datum = BayesTrainDatum.find_or_initialize_by(url: url)
    bayes_train_datum.judge = judge
    bayes_train_datum.page_id = page_id
    bayes_train_datum.save
  end
  #教師データからベイズ用の確率更新
  def train
    BayesTrainDatum.includes({page: :inverted_indices}).find_each do |x|
      case x.judge
      when -1
        judge = :false
      when 0
        next
      when 1
        judge = :true
      end
      words = x.page.words_count
      @vocabularies.merge(words.keys)
      @word_count[judge] ||= {}
      @word_count[judge].merge!(words) {|key,val1,val2| val1 + val2}
      category_count_up(judge)
    end
  end
  #トレーニング済データを保存する関数
  def save
    bayes_datum = BayesDatum.find_or_initialize_by(id: 1)
    bayes_datum.vocabularies = @vocabularies
    bayes_datum.word_count = @word_count
    bayes_datum.category_count = @category_count
    bayes_datum.save
  end
  #トレーニング済データを呼び出す関数
  def load
    bayes_datum = BayesDatum.find_by(id: 1)
    if bayes_datum
      @vocabularies = bayes_datum.vocabularies
      @word_count = bayes_datum.word_count
      @category_count = bayes_datum.category_count
    else
      puts "bayes datum is not"
    end
  end

  #pageを削除した時page_idを更新する
  def update_page_id
    BayesTrainDatum.transaction do
      BayesTrainDatum.pluck(:id, :url).each do |(id, url)|
        puts "updated!"
        page_id = Page.find_by(url: url).id
        bayes_train_datum = BayesTrainDatum.find_by(id: id)
        bayes_train_datum.page_id = page_id
        bayes_train_datum.save
      end
    end
  end

  def category_count_up judge
    @category_count[judge] ||= 0
    @category_count[judge] += 1
  end

  def classifier words
    return :noword if words.empty?
    best = nil
    maxint = 1 << (1.size * 8 - 2) - 1
    max = -maxint

    for cat in @category_count.keys
      prob = score(words, cat)
      if prob > max
        max = prob
        best = cat
      end
    end
    best
  end

  def score words, cat
    score = Math.log(priorprob(cat))
    words.each do |word,count|
      score += Math.log(wordprob(word, cat)) * count
    end
    score
  end

  def priorprob cat
    prob = @category_count[cat] / @category_count.values.inject(:+).to_f
    prob
  end

  def incategory word, cat
    #あるカテゴリの中に単語が登場した回数を返す
    if @word_count[cat].has_key?(word)
      return @word_count[cat][word].to_f
    else
      return 0.0
    end
  end

  def wordprob word, cat
    # P(word|cat)が生起する確率を求める
    prob = (incategory(word, cat) + 1.0) / (@word_count[cat].values.inject(:+) + @vocabularies.length * 1.0)
    prob
  end
end
