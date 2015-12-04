class BayesDatum < ActiveRecord::Base
  serialize :vocabularies
  serialize :word_count
  serialize :category_count
end
