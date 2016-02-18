function on_keydown_quicksearch(event) {
  var key;
  var element = $(this);

  if (window.event)
    key = window.event.keyCode;   // IE
  else
    key = event.which;            // Firefox

  if (key != 13)
    return true;

  var search_term = $(element);
  var value       = search_term.val();
  if (!value)
    return true;

  url = {
    frame_header_contact_search: "ct.pl?action=list_contacts&INPUT_ENCODING=utf-8&filter.status=active&search_term=",
    frame_header_parts_search:   "ic.pl?action=generate_report&INPUT_ENCODING=utf-8&searchitems=assembly&all="
  }[element.attr('id')];

  window.location.href = url + encodeURIComponent(value);

  return false;
}
$(function(){
  $('#frame_header_contact_search').keydown(on_keydown_quicksearch);
  $('#frame_header_parts_search').keydown(on_keydown_quicksearch);
});
