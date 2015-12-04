class QueueIndex < ActiveRecord::Base
  validates :url, uniqueness: true
end
