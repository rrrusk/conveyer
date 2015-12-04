require 'natto'
require 'nokogiri'
class Indexer
  def initialize
    #setに変えるかも
    @crawls = []
    @words = Hash.new(0)
    @inverted_indices = Hash.new {|h,k| h[k] = []}
    #教育済みデータを何回も呼び出さないためにここで宣言
    @naive_bayes = NaiveBayes.new
    @naive_bayes.load
    @bayes_t = 0
    @indexed = []
    @blacklist = YAML.load_file('./blacklist.yml').join('|') rescue ''
  end

  #queue_indexに入ってる奴を解析
  def exec
    begin
      i = 0

      QueueIndex.find_each do |x|
        analyse(x.url, x.body)
        @indexed << x.id
        i += 1

        if i >= 1000
          i = 0
          save
        end
      end

      save
      p Page.count
      puts "bayes: #{@bayes_t}"
    rescue Interrupt
      puts "Interrupt: indexer\nnow saving"
      save
      puts "saved!"
      exit(0)
    end
  end

  def save
    apply_words
    apply_inverted_indices
    apply_queue_crawls
    delete_queue_indices
  end

  def analyse url, body
    print "#{url}, "

    doc = Nokogiri::HTML.parse(body)
    words = word_count_html(body)
    title = page_title(doc, url)
    tfs = WordExtraction::tfs(words)

    #ナイーブベイズして技術系か判定
    judge = ""
    @bayes_t += Benchmark.realtime do
      judge = @naive_bayes.classifier(words).to_s
    end

    state =
      case judge
      when "noword"; "no word"
      when "false"; "unrelated"
      else "correct"
      end

    #wordsは転置インデックスのと所に数を入れておけば作れる
    page = {url: url, title: title, state: state}
    page_id = apply_page(page)

    if state == "correct"
      links = get_links(url, doc)
      @crawls |= blacklist(links)
      tfs.each do |word, val|
        val[:page_id] = page_id
        @inverted_indices[word] << val
      end
    end

    words.each do |key, val|
      @words[key] += 1
    end
  end

  #形態素解析して単語の出現回数取得
  def word_count_nokogiri doc
    words = Hash.new(0)
    doc.css("script,style,noscript,svg").remove

    doc.css('body').each do |elm|
      text = elm.content.gsub(/(\t|\s|\n|\r|\f|\v)/,"")
      words.merge!(word_count(text)) {|k,v1,v2| v1 + v2}
    end

    return trimming(words)
  end

  def blacklist urls
    urls.delete_if {|url| %r{#{@blacklist}} === url}
  end

  def get_links url, doc
    links = []
    doc.css("a[href]").each do |a|
      link = a['href'].strip
      next unless link
      abs = to_absolute(link, url) rescue next
      links << abs.normalize.to_s
    end
    return links.uniq
  end

  def to_absolute link, url
    # remove anchor
    link.gsub!(/#.*$/,'')
      .gsub!(/\?.*$/,'')
    relative = URI(link)
    absolute = relative.absolute? ? relative : URI(url).merge(relative)

    absolute.path = '/' if absolute.path.empty?
    return absolute
  end

  def trimming words
    words.select {|k,v| k.length > 1}
  end

  def word_count_html html
    content, title = ExtractContent.analyse(html)
    return word_count(content)
  end

  def word_count text
    nm = Natto::MeCab.new
    words = Hash.new(0)

    begin
      nm.parse(text) do |n|
        words[n.surface.downcase] += 1 if n.feature.match("名詞") && ! n.feature.match(/,(数|非自立|代名詞)/)
      end
    rescue => e
      puts "word_count_error: #{e}"
    end

    return words
  end

  def page_title doc, url
    begin
      title = doc.at('title').content
      title = url.gsub(%r{.*?//(.*)}, '\1') if title.empty?
    rescue
      title = url.gsub(%r{.*?//(.*)}, '\1')
    end

    return title
  end

  #ナイーブベイズしてプログラミング関連か調べる。違ったら破棄
  #単語の出現回数保存
  def apply_page page
    obj = Page.create(page)
    return obj.id
  end

  def apply_words
    Word.transaction do
      @words.each do |word, count|
        Word.find_or_initialize_by(name: word).increment(:count, count).save
      end
    end
    @words = Hash.new(0)
  end

  #転置リスト更新
  def apply_inverted_indices
    InvertedIndex.transaction do
      @inverted_indices.each do |word, values|
        word_id = Word.find_or_create_by(name: word).id
        values.each do |value|
          value[:word_id] = word_id
          InvertedIndex.create(value)
        end
      end
    end
    @inverted_indices = Hash.new {|h,k| h[k] = []}
  end

  def delete_queue_indices
    QueueIndex.delete(@indexed)
    @indexed = []
  end

  def apply_queue_crawls
    QueueCrawl.transaction do
      @crawls.each do |x|
        QueueCrawl.create(url: x)
      end
    end
    @crawls = []
  end
end
