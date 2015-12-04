$ ->
  $('.page').click (e) ->
    pageId = $(@).data('id')
    console.log pageId
    $.post '/read_page',
      page_id: pageId
