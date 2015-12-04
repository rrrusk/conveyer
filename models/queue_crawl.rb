class QueueCrawl < ActiveRecord::Base
  validates :url, uniqueness: true
  validates_format_of :url, without: /\.(zip|jpg|jpeg|png|gif|svg|mp3)\z/
end
