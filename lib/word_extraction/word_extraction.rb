require 'matrix'
require 'uri'

class WordExtraction
  #tf-idf法で抽出
  def tf_idf tfs, n
    scores = {}

    if @all_count
      all_count = @all_count
    else
      all_count = Word.where(id: tfs.keys).pluck(:id, :count).to_h
    end

    tfs.each do |word, score|
      #idfは流動的なのでデータベースにキャッシュするなどできるのはtfのみ
      df = all_count[word]
      idf = Math.log(n / df.to_f) + 1
      scores[word] = score / idf
    end

    return scores
  end

  def self.tfs words
    count_sum = words.inject(0) {|sum, (key, val)| sum + val}
    tfs = {}

    words.each do |word, count|
      tf = count / count_sum.to_f
      tfs[word] = {tf: tf, count: count}
    end

    return tfs
  end

  def cosine_similarity vector_hash1, vector_hash2
    vector_hash1, vector_hash2 = merge_vector(vector_hash1, vector_hash2)
    vector1 = Vector.elements(to_vector_array(vector_hash1))
    vector2 = Vector.elements(to_vector_array(vector_hash2))
    return vector2.inner_product(vector1)/(vector1.norm * vector2.norm)
  end

  def merge_vector vector_hash1, vector_hash2
    diff1 = vector_hash2.keys - (vector_hash1.keys & vector_hash2.keys)
    diff2 = vector_hash1.keys - (vector_hash1.keys & vector_hash2.keys)
    diff1.each {|val| vector_hash1[val] = 0.0}
    diff2.each {|val| vector_hash2[val] = 0.0}
    return [vector_hash1,vector_hash2]
  end

  def to_vector_array hash
    return hash.to_a.sort_by {|x| x[0]}.map {|x| x[1]}
  end

  #関連度の高そうなものだけ取得
  #tf_idfを受け取りpage_idの配列を返す
  def choose_pages scores, n
    min_appearance_rate = 5
    word_ids = scores.keys.delete_if {|id| n / @all_count[id].to_f < min_appearance_rate}
    return InvertedIndex.where(word_id: word_ids).uniq.pluck(:page_id)
  end

  def relative_pages scores
    relative_pages = []
    n = Page.count

    @all_count = Word.pluck(:id, :count).to_h

    page_ids = choose_pages(scores.dup, n)
    index = InvertedIndex.where(page_id: page_ids).pluck(:page_id, :word_id, :tf)
    pages = Hash.new {|h,k| h[k] = {}}

    index.each do |(page_id, word_id, tf)|
      pages[page_id][word_id] = tf
    end

    pages.each do |page_id, tfs|
      com_scores = tf_idf(tfs, n)
      similarity = cosine_similarity(scores.dup, com_scores)
      relative_pages << {
        similarity: similarity,
        id: page_id
      }
    end

    #0ベクトルはNaNになるのでそれを弾く
    relative_pages = relative_pages.reject {|x| x[:similarity].nan?}
                        .sort_by {|x| x[:similarity]}
                        .reverse
    return relative_pages
  end

  def relative_pages_url url
    page = Page.find_by(url: url)
    if page
      title = page.title
      tfs = page.words_id_tf
    else
      begin
        URI(url)
        body = open(url).read.toutf8
      rescue => e
        p e
        body = ""
      end
      indexer = Indexer.new
      doc = Nokogiri::HTML.parse(body)
      words = indexer.word_count_html(body)
      title = indexer.page_title(doc, url)
      tfs_name = WordExtraction::tfs(words).map do |word, val|
        [word, val[:tf]]
      end.to_h
      word_ids = Word.where(name: tfs_name.keys).pluck(:name, :id).to_h
      tfs = {}
      word_count = Word.count
      i = 5
      tfs_name.each do |name, tf|
        if word_ids[name]
          tfs[word_ids[name]] = tf
        else
          tfs[word_count+i] = tf
          i += 1
        end
      end
    end
    scores = tf_idf(tfs, Page.count)
    return title, relative_pages(scores).delete_if{|x| x[:id] == page.id if page}
  end
end
