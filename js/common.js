function setupPoints(numberformat, wrongFormat) {
  decpoint = numberformat.substring((numberformat.substring(1, 2).match(/\.|\,/) ? 5 : 4), (numberformat.substring(1, 2).match(/\.|\,/) ? 6 : 5));
  if (numberformat.substring(1, 2).match(/\.|\,/)) {
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
  if(decpoint && thpoint && thpoint == decpoint) {
    return show_alert_and_focus(input_name, wrongNumberFormat);
  }
  var test_val = input_name.value;
  if(thpoint && thpoint == ','){
    test_val = test_val.replace(/,/g, '');
  }
  if(thpoint && thpoint == '.'){
    test_val = test_val.replace(/\./g, '');
  }
  if(decpoint && decpoint == ','){
    test_val = test_val.replace(/,/g, '.');
  }
  var forbidden = test_val.match(/[^\s\d\(\)\-\+\*\/\.]/g);
  if (forbidden && forbidden.length > 0 ){
    return show_alert_and_focus(input_name, wrongNumberFormat);
  }

  try{
    eval(test_val);
  }catch(err){
    return show_alert_and_focus(input_name, wrongNumberFormat);
  }

}

function check_right_date_format(input_name) {
  if(input_name.value == "") {
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
      return show_alert_and_focus(input_name, wrongDateFormat);
    }
  }
  else {
    if (dateFormat.lastIndexOf("y") == 3 && !matching.test(input_name.value)) {
      return show_alert_and_focus(input_name, wrongDateFormat);
    }
  }
}

function validate_dates(input_name_1, input_name_2) {
  var tempArray1 = new Array();
  var tempArray2 = new Array();
  tempArray1 = getDateArray(input_name_1);
  tempArray2 = getDateArray(input_name_2);
  if(check_right_date_format(input_name_1) && check_right_date_format(input_name_2)) {
    if(!((new Date(tempArray2[0], tempArray2[1], tempArray2[2])).getTime() >= (new Date(tempArray1[0], tempArray1[1], tempArray1[2])).getTime())) {
      show_alert_and_focus(input_name_1, wrongDateFormat);
      return show_alert_and_focus(input_name_2, wrongDateFormat);
    }
    if(!((new Date(tempArray2[0], tempArray2[1], tempArray2[2])).getTime() >= (new Date(1900, 1, 1)).getTime())) {
      show_alert_and_focus(input_name_1, wrongDateFormat);
      return show_alert_and_focus(input_name_2, wrongDateFormat);
    }
  }
}

function getDateArray(input_name) {
  formatArray[2] = input_name.value.substring(dateFormat.indexOf("d"), 2);
  formatArray[1] = input_name.value.substring(dateFormat.indexOf("m"), 2);
  formatArray[0] = input_name.value.substring(dateFormat.indexOf("y"), (dateFormat.length == 10 ? 4 : 2));
  if(dateFormat.length == 8) {
    formatArray[0] += (formatArray[0] < 70 ? 2000 : 1900);
  }
  return formatArray;
}

function show_alert_and_focus(input_name, errorMessage) {
  input_name.select();
  alert(errorMessage + "\n\r\n\r--> " + input_name.value);
  input_name.focus();
  return false;
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

$(document).ready(function () {
  $('input').focus(function(){
    if (focussable(this)) window.focused_element = this;
  });

  // Lowest priority: first focussable element in form.
  set_cursor_to_first_element();

  // Medium priority: class set in template
  var initial_focus = $(".initial_focus").filter(':visible')[0];
  if (initial_focus)
    $(initial_focus).focus();

  // legacy. sone forms install these
  if (typeof fokus == 'function') { fokus(); return; }
  if (focus_by_name('cursor_fokus')) return;
});

$('form').submit(function(){
  if (window.focused_element)
    document.forms[0].cursor_fokus.value = window.focused_element.name;
});
