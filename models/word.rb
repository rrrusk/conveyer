class Word < ActiveRecord::Base
  has_many :inverted_indices
  has_many :pages, through: :inverted_indices
end
