function centerParms(width,height,extra) {
  xPos = (screen.width - width) / 2;
  yPos = (screen.height - height) / 2;

  string = "left=" + xPos + ",top=" + yPos;

  if (extra)
    string += "width=" + width + ",height=" + height;

  return string;
}

function get_input_value(input_name) {
  var the_input = document.getElementsByName(input_name);
  if (the_input && the_input[0])
    return the_input[0].value;
  return '';
}

function set_cursor_position(n) {
  $('[name=' + n + ']').focus();
}

function focussable(e) {
  return e && e.name && e.type != 'hidden' && e.type != 'submit' && e.disabled != true;
}

function set_cursor_to_first_element(){
  var df = document.forms;
  for (var f = 0; f < df.length; f++)
    for (var i = 0; i < df[f].length; i++)
      if (focussable(df[f][i]))
        try { df[f][i].focus(); return } catch (er) { }
}

function getElementByIndirectName(name){
  var e = document.getElementsByName(name)[0];
  if (e) return document.getElementsByName(e.value)[0];
}

function focus_by_name(name){
  var f = getElementByIndirectName(name);
  if (focussable(f)) {
    set_cursor_position(f.name);
    return true;
  }
  return false;
}

$(function () {
  $('input').focus(function(){
    if (focussable(this)) window.focused_element = this;
  });

  // setting focus inside a tabbed area fails if this is encountered before the tabbing is complete
  // in that case the elements count as hidden and jquery aborts .focus()
  setTimeout(function(){
    // Lowest priority: first focussable element in form.
    set_cursor_to_first_element();

    // Medium priority: class set in template
    var initial_focus = $(".initial_focus").filter(':visible')[0];
    if (initial_focus)
      $(initial_focus).focus();

    // special: honour focus_position
    // if no higher priority applies set focus to the appropriate element
    if ($("#display_row")[0] && kivi.myconfig.focus_position) {
      switch(kivi.myconfig.focus_position) {
        case 'last_partnumber'  : $('#display_row tr.row:gt(-3):lt(-1) input[name*="partnumber"]').focus(); break;
        case 'last_description' : $('#display_row tr.row:gt(-3):lt(-1) input[name*="description"]').focus(); break;
        case 'last_qty'         : $('#display_row tr.row:gt(-3):lt(-1) input[name*="qty"]').focus(); break;
        case 'new_partnumber'   : $('#display_row tr:gt(1) input[name*="partnumber"]').focus(); break;
        case 'new_description'  : $('#display_row tr:gt(1) input[name*="description"]').focus(); break;
        case 'new_qty'          : $('#display_row tr:gt(1) input[name*="qty"]').focus(); break;
      }
    }

    // all of this screws with the native location.hash focus, so reimplement this as well
    if (location.hash) {
      var hash_name = location.hash.substr(1);
      var $hash_by_id = $(location.hash + ':visible');
      if ($hash_by_id.length > 0) {
        $hash_by_id.get(0).focus();
      } else {
        var $by_name = $('[name=' + hash_name + ']:visible');
        if ($by_name.length > 0) {
          $by_name.get(0).focus();
        }
      }
    }

    // legacy. some forms install these
    if (typeof fokus == 'function') { fokus(); return; }
    if (focus_by_name('cursor_fokus')) return;
  }, 0);
});

$('form').submit(function(){
  if (window.focused_element)
    document.forms[0].cursor_fokus.value = window.focused_element.name;
});
