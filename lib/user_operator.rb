require 'matrix'
require 'date'

class UserOperator
  def make_news
    User.find_each do |user|
      relative_pages = user_relative_pages(user.id)[0..100]
      apply_user_pages(relative_pages, user.id)
    end
  end

  def login name, password
    user = User.find_by(name: name, password: password)
    if user
      return true
    else
      return false
    end
  end

  def register name, password
    user = User.find_by(name: name)
    if user
      return false
    else
      User.create(name: name, password: password)
      return true
    end
  end

  def update_parameters tfs, user_id = 1
    page_weight = 0.3
    user = User.find_by(id: user_id)
    user_tfs = user.user_tfs.pluck(:word_id, :tf).to_h
    #単位ベクトル同士を足したいので長さを求める
    ut_length = vector_length(user_tfs.values)
    t_length = vector_length(tfs.values)
    keys = user_tfs.keys | tfs.keys
    new_tfs = {}

    if ut_length.zero?
      new_tfs = tfs.map{|id, tf| [id, tf * page_weight]}.to_h
    elsif t_length.zero?
      new_tfs = user_tfs.map{|id, tf| [id, tf * (1.0 - page_weight)]}.to_h
    else
      keys.each do |word_id|
        user_tf = user_tfs[word_id] || 0.0
        #基本的にすでにインデックスしてるものを使うのでtfが存在しないことはないはず
        tf = tfs[word_id] || 0.0
        new_tfs[word_id] = user_tf / ut_length * (1.0 - page_weight) + tf / t_length * page_weight
      end
    end

    #単語更新
    apply_user_tfs(new_tfs, user_id)
  end

  def vector_length values
    vector1 = Vector.elements(values).norm
  end

  def user_relative_pages user_id
    puts "user_relative_pages"
    user = User.find_by(id: user_id)
    #tf数制限はidfが多いものが上に来るので無意味
    user_tfs = user.user_tfs.pluck(:word_id, :tf).to_h
    word_extraction = WordExtraction.new
    return word_extraction.relative_pages(user_tfs)
  end

  def apply_user_tfs tfs, user_id
    UserTf.transaction do
      tfs.each do |word_id, tf|
        user_tf = UserTf.find_or_initialize_by(user_id: user_id, word_id: word_id)
        user_tf.tf = tf
        user_tf.save
      end
    end
  end

  def apply_user_pages pages, user_id
    UserPage.transaction do
      UserPage.destroy_all
      pages.each do |page|
        UserPage.create(user_id: user_id, page_id: page[:id], similarity: page[:similarity])
      end
    end
  end
end
