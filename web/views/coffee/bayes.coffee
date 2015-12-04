$ ->
  $('.true').click ->
    pageId = $(@).data('id')
    console.log pageId
    $.post '/judge',
      page_id: pageId
      judge: 1
  $('.false').click ->
    pageId = $(@).data('id')
    console.log pageId
    $.post '/judge',
      page_id: pageId
      judge: -1
