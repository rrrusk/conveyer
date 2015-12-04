class Page < ActiveRecord::Base
  has_one :bayes_train_datum
  has_many :inverted_indices
  validates :url, uniqueness: true
  has_many :words, through: :inverted_indices

  def words_count
    count = self.inverted_indices.pluck(:word_id, :count).to_h
    names = Word.where(id: count.keys).pluck(:id, :name).to_h
    words_count = {}
    names.each do |id, name|
      words_count[name] = count[id]
    end
    return words_count
  end

  def words_id_tf
    tfs = self.inverted_indices.pluck(:word_id, :tf).to_h
  end

  def words_tf
    tfs = self.inverted_indices.pluck(:word_id, :tf).to_h
    names = Word.where(id: tfs.keys).pluck(:id, :name).to_h
    words_tf = {}
    names.each do |id, name|
      words_tf[name] = tfs[id]
    end
    return words_tf
  end
end
