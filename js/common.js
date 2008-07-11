if (!window.a_onload_functions)   a_onload_functions   = new Object();
if (!window.a_onsubmit_functions) a_onsubmit_functions = new Object();
if (!window.a_onfocus_functions)  a_onfocus_functions  = new Object();
window.focused_element = null;

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

function set_longdescription_window(input_name) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  url = "common.pl?" +
    "action=set_longdescription&" +
    "longdescription=" + encodeURIComponent(document.getElementsByName(input_name)[0].value) + "&" +
    "input_name=" + encodeURIComponent(input_name) + "&"
  window.open(url, "_new_generic", parm);
  }

function check_right_number_format(input_name) {
  if(decpoint == thpoint) {
    return show_alert_and_focus(input_name, wrongNumberFormat);
  }
  if(decpoint == ',') {
    var decnumbers = input_name.value.split(',');
  }
  else {
    var decnumbers = input_name.value.split('.');
  }
  if(decnumbers.length == 2) {
    if(decnumbers[1].length > 2)  {
      return show_alert_and_focus(input_name, wrongNumberFormat);
    }
  }
  else {
    if(decnumbers.length > 2) {
      return show_alert_and_focus(input_name, wrongNumberFormat);
    }
    if(!thpoint) {
      if(decnumbers[0].match(/\D/)) {
        return show_alert_and_focus(input_name, wrongNumberFormat);
      }
    }
  }
}

function check_right_date_format(input_name) {
  if(input_name.value == "") {
    return true;
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

a_onfocus_functions["focus_listener"] = (function (event) { 
  if (focussable(event.target)) window.focused_element = event.target;
});

a_onsubmit_functions["get_cursor_position"] = (function () {
  if (window.focused_element)
    document.forms[0].cursor_fokus.value = window.focused_element.name;
});

function set_cursor_position(n) {
  document.getElementsByName(n)[0].focus();
}

a_onload_functions["restore_cursor_position"] = (function () {
  var e = document.getElementsByName('cursor_fokus')[0];
  if (e) var f = document.getElementsByName(e.value)[0];
  if (focussable(f)) set_cursor_position(f.name)
    else set_cursor_to_first_element();
});

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

function add_event(e, type, fn, c) {
  var ret = 0;
  if (e.addEventListener) e.addEventListener(type, fn, c)
  else if (e.attachEvent) e.attachEvent('on' + type, fn)
  else e['on' + type] = fn;
} 

function do_load_events() {
  for (var name in window.a_onload_functions)   add_event(window, "load",   window.a_onload_functions[name],   false);
  for (var name in window.a_onsubmit_functions) add_event(window, "submit", window.a_onsubmit_functions[name], false);
  for (var name in window.a_onfocus_functions)  add_event(window, "focus",  window.a_onfocus_functions[name],  false);
}
do_load_events();
