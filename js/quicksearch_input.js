function on_keydown_quicksearch(element, event) {
  var key;

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

  var url = "ct.pl?action=list_contacts&INPUT_ENCODING=utf-8&filter.status=active&search_term=" + encodeURIComponent(value);

  search_term.val('');
  window.location.href = url;

  return false;
}
