
function setupPoints(numberformat, wrongFormat) {
  decpoint = numberformat.substring((numberformat.substring(1, 2).match(/.|,/) ? 5 : 4), (numberformat.substring(1, 2).match(/.|,/) ? 6 : 5));
  if (numberformat.substring(1, 2).match(/.|,/)) {
    thpoint = numberformat.substring(1, 2); 
  }
  else {
    thpoint = null;
  }
  wrongformat = wrongFormat;  
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
    "login=" +  encodeURIComponent(document.getElementsByName("login")[0].value)+ "&"+
    "password=" + encodeURIComponent(document.getElementsByName("password")[0].value) + "&" +
    "path=" + encodeURIComponent(document.getElementsByName("path")[0].value) + "&" +
    "longdescription=" + escape(document.getElementsByName(input_name)[0].value) + "&" +
    "input_name=" + escape(input_name) + "&"
  window.open(url, "_new_generic", parm);
  }

  function check_right_date_format(input_name) {
    var decnumbers = input_name.value.split(decpoint);
    if(thpoint) {
      var thnumbers = input_name.value.split(thpoint);
      if(thnumbers[thnumbers.length-1].match(/.+decpoint$/g)) {
        thnumbers[thnumbers.length-1] = thnumbers[thnumbers.length-1].substring(thnumbers[thnumbers.length-1].length-1);
      }
      if(thnumbers[thnumbers.length-1].match(/.+decpoint\d$/g)) {
        thnumbers[thnumbers.length-1] = thnumbers[thnumbers.length-1].substring(thnumbers[thnumbers.length-1].length-2);
      }  
      if(thnumbers[thnumbers.length-1].match(/.+decpoint\d\d$/g)) {
        thnumbers[thnumbers.length-1] = thnumbers[thnumbers.length-1].substring(thnumbers[thnumbers.length-1].length-3);
      }  
      for(var i = 1; i < thnumbers.length; i++) {
        if(!thnumbers[i].match(/\d\d\d/g)) {
          return show_alert_and_focus(input_name);
        }
        if(thnumbers[i].match(/.*decpoint.*|.*thpoint.*/g)) {
          return show_alert_and_focus(input_name);
        }
      }
      if(decnumbers.length > 2 || (decnumbers.length > 1 ? (decnumbers[1].length > 2) : false)) {
        return show_alert_and_focus(input_name);
      }
    }
    else {
      if(decnumbers.length > 1 || decnumbers[0].length > 2) {
        return show_alert_and_focus(input_name);
      }
    }
  }
  
  function show_alert_and_focus(input_name) {
    input_name.select();
    alert(wrongformat + "\n\r\n\r--> " + input_name.value);
    input_name.focus();
    return false;
  }
  
