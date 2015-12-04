#one_pageのanemoneを自前に変更
require 'anemone'
require 'kconv'
require 'rss'

class Crawler
  def initialize
    @indices = []
  end
  #queue_crawlsのやつをひたすら回す。
  def crawl
    begin
      p QueueCrawl.count
      ids = QueueCrawl.pluck(:id)
      urls = sift_urls(QueueCrawl.pluck(:url))
      one_page(urls)
      delete_queue_crawls(ids)
    rescue Interrupt
      puts "Interrupt: crawl\nnow saving"
      save
      puts "saved!"
      exit(0)
    end
  end

  def sift_urls urls
    urls.delete_if do |link|
      QueueIndex.exists?(url: link) || Page.exists?(url: link)
    end
  end
  #anemoneこれは手動実行で
  def all_pages urls
    begin
      options = {
        skip_query_strings: true,
        storage: Anemone::Storage.PStore('anemone.db')
      }

      anemone_exec(urls, options)
    rescue Interrupt
      puts "Interrupt:all_pages"
      save
      exit
    end
  end

  def one_page urls
    options = {
      skip_query_strings: true,
      storage: Anemone::Storage.PStore('anemone.db'),
      depth_limit: 0
    }

    anemone_exec(urls, options)
  end

  def anemone_exec url, options
    Anemone.crawl(url,options) do |anemone|
      anemone.on_every_page do |page|
        every_page(page)
      end

      anemone.after_crawl do |page|
        apply_queue_indices
      end
    end
  end

  def every_page page
    if page.code == 200 && page.content_type.match(/^text\/html/)
      print "#{page.url.normalize.to_s}, "
      @indices << {url: page.url.normalize.to_s, body: page.body.toutf8}
      apply_queue_indices if @indices.length >= 20
    elsif page.code == 200 && !page.content_type.match(/^text\/html/)
      Page.create(url: page.url.normalize.to_s, state: "not html")
    else
      Page.create(url: page.url.normalize.to_s, state: "error")
    end
  end
  #はてぶとかrssとかその他
  def rss url
    rss = RSS::Parser.parse(url)
    crawls = []

    rss.items.each do |item|
      crawls << item.link
    end

    apply_queue_crawls(crawls)
  end
  #ナイーブベイズの教師データが存在するものをダウンロード。page_id貼り直す必要あり
  def bayes
    apply_queue_crawls(BayesTrainDatum.pluck(:url))
  end
  #queue_indicesに追加する部分
  def apply_queue_indices
    QueueIndex.transaction do
      @indices.each do |x|
        QueueIndex.create(url: x[:url], body: x[:body])
      end
    end
    @indices = []
  end
  #queue_crawlsに追加する部分
  def apply_queue_crawls crawls
    QueueCrawl.transaction do
      crawls.each do |x|
        QueueCrawl.create(url: x)
      end
    end
  end

  def delete_queue_crawls ids
    QueueCrawl.delete(ids)
  end

  def save
    apply_queue_indices unless @indices.empty?
  end
end
