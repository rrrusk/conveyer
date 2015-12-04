class User < ActiveRecord::Base
  has_many :user_tfs
  has_many :user_pages
  validates :name, uniqueness: true
end
