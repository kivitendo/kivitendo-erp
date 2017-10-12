function setupPoints(numberformat, wrongFormat) {
  decpoint = numberformat.substring((numberformat.substring(1, 2).match(/\.|\,|\'/) ? 5 : 4), (numberformat.substring(1, 2).match(/\.|\,|\'/) ? 6 : 5));
  if (numberformat.substring(1, 2).match(/\.|\,|\'/)) {
    thpoint = numberformat.substring(1, 2);
  }
  else {
    thpoint = null;
  }
  wrongNumberFormat = wrongFormat + " ( " + numberformat + " ) ";
}

function setupDateFormat(setDateFormat, setWrongDateFormat) {
  dateFormat = setDateFormat;
  wrongDateFormat = setWrongDateFormat + " ( " + setDateFormat + " ) ";
  formatArray = new Array();
  if(dateFormat.match(/^\w\w\W/)) {
    seperator = dateFormat.substring(2,3);
  }
  else {
    seperator = dateFormat.substring(4,5);
  }
}

function centerParms(width,height,extra) {
  xPos = (screen.width - width) / 2;
  yPos = (screen.height - height) / 2;

  string = "left=" + xPos + ",top=" + yPos;

  if (extra)
    string += "width=" + width + ",height=" + height;

  return string;
}

function check_right_number_format(input_name) {
  var test_val = input_name.value;
  if(thpoint && thpoint == ','){
    test_val = test_val.replace(/,/g, '');
  }
  if(thpoint && thpoint == '.'){
    test_val = test_val.replace(/\./g, '');
  }
  if(thpoint && thpoint == "'"){
    test_val = test_val.replace(/\'/g, '');
  }
  if(decpoint && decpoint == ','){
    test_val = test_val.replace(/,/g, '.');
  }
  var forbidden = test_val.match(/[^\s\d\(\)\-\+\*\/\.]/g);
  if (forbidden && forbidden.length > 0 ){
    return annotate(input_name, kivi.t8('wrongformat'), kivi.myconfig.numberformat);
  }

  try{
    eval(test_val);
  }catch(err){
    return annotate(input_name, kivi.t8('wrongformat'), kivi.myconfig.numberformat);
  }

  return annotate(input_name);
}

function check_right_date_format(input_name) {
  if(input_name.value == "") {
    annotate(input_name);
    return true;
  }

  if ( ( input_name.value.match(/^\d+$/ ) ) && !(dateFormat.lastIndexOf("y") == 3) ) {
    // date shortcuts for entering date without separator for three date styles, e.g.
    // 31122014 -> 12.04.2014
    // 12312014 -> 12/31/2014
    // 31122014 -> 31/12/2014

    if (input_name.value.match(/^\d{8}$/)) {
      input_name.value = input_name.value.replace(/^(\d\d)(\d\d)(\d\d\d\d)$/, "$1" + seperator + "$2" + seperator + "$3")
    } else if (input_name.value.match(/^\d{6}$/)) {
      // 120414 -> 12.04.2014
      input_name.value = input_name.value.replace(/^(\d\d)(\d\d)(\d\d)$/, "$1" + seperator + "$2" + seperator + "$3")
    } else if (input_name.value.match(/^\d{4}$/)) {
      // 1204 -> 12.04.2014
      var today = new Date();
      var year = today.getYear();
      if (year < 999) year += 1900;
      input_name.value = input_name.value.replace(/^(\d\d)(\d\d)$/, "$1" + seperator + "$2");
      input_name.value = input_name.value + seperator + year;
    } else  if ( input_name.value.match(/^\d{1,2}$/ ) ) {
      // assume the entry is the day of the current month and current year
      var today = new Date();
      var day = input_name.value;
      var month = today.getMonth() + 1;
      var year = today.getYear();
      if( day.length == 1 && day < 10) {
        day='0'+day;
      };
      if(month<10) {
        month='0'+month;
      };
      if (year < 999) year += 1900;
      if ( dateFormat.lastIndexOf("d") == 1) {
        input_name.value = day + seperator + month + seperator + year;
      } else {
        input_name.value = month + seperator + day + seperator + year;
      }
    };
  }

  var matching = new RegExp(dateFormat.replace(/\w/g, '\\d') + "\$","ig");
  if(!(dateFormat.lastIndexOf("y") == 3) && !matching.test(input_name.value)) {
    matching = new RegExp(dateFormat.replace(/\w/g, '\\d') + '\\d\\d\$', "ig");
    if(!matching.test(input_name.value)) {
      return annotate(input_name, kivi.t8('Falsches Datumsformat!'), kivi.myconfig.dateformat);
    }
  }
  else {
    if (dateFormat.lastIndexOf("y") == 3 && !matching.test(input_name.value)) {
      return annotate(input_name, kivi.t8('Falsches Datumsformat!'), kivi.myconfig.dateformat);
    }
  }
  return annotate(input_name);
}

function annotate(input_name, error, expected) {
  var $e = $(input_name);
  if (error) {
    $e.addClass('kivi-validator-invalid');
    var tooltip = error + ' (' + expected + ')';
    if ($e.hasClass('tooltipstered'))
      $e.tooltipster('destroy');

    $e.tooltipster({
      content: tooltip,
      theme: 'tooltipster-light',
    });
    $e.tooltipster('show');
  } else {
    $e.removeClass('kivi-validator-invalid');
    if ($e.hasClass('tooltipstered'))
      $e.tooltipster('destroy');
  }
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
