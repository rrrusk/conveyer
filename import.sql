create table queue_crawls (
  id integer primary key,
  url string unique
);
create index queue_crawl_idx on queue_crawls(url);
create table queue_indices (
  id integer primary key,
  url string unique,
  body text
);
create index queue_index_idx on queue_indices(url);
create table pages (
  id integer primary key,
  url string unique,
  title string,
  state string,
  updated_at
);
create index page_idx on pages(url);
create table words (
  id integer primary key,
  name string unique,
  count integer default 0
);
create index word_idx on words(name);
create table inverted_indices (
  id integer primary key,
  page_id integer,
  word_id integer,
  count integer default 0,
  tf real default 0
);
create index inverted_indices_page_idx on inverted_indices(page_id);
create index inverted_indices_word_idx on inverted_indices(word_id);
create table bayes_train_data (
  id integer primary key,
  page_id integer,
  url string,
  judge integer default 0
  /* -1でprogramingの記事じゃない1で記事0で未判定*/
);
create table bayes_data (
  id integer primary key,
  vocabularies text,
  word_count text,
  category_count text
);
drop table users;
create table users (
  id integer primary key,
  name text unique,
  password text
);
drop table user_tfs;
create table user_tfs (
  id integer primary key,
  user_id integer,
  word_id integer,
  tf real default 0
);
create index user_tfs_idx on user_tfs(user_id, word_id);
drop table user_pages;
create table user_pages (
  id integer primary key,
  user_id integer,
  page_id integer,
  similarity real,
  updated_at
);
create index user_pages_idx on user_pages(user_id);
