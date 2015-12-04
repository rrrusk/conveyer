class InvertedIndex < ActiveRecord::Base
  belongs_to :page, :dependent => :destroy
  belongs_to :word, :dependent => :destroy
end
