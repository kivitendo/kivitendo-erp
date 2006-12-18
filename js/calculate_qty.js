function calculate_qty_selection_window(input_name, alu, formel, row) {
  var parm = centerParms(600,500) + ",width=600,height=500,status=yes,scrollbars=yes";
  var name = document.getElementsByName(input_name)[0].value;
  if (document.getElementsByName(alu)[0].value == "1") {
    var action = "calculate_alu";
    var qty = document.getElementsByName("qty_" + row)[0].value;
    var description = document.getElementsByName("description_" + row)[0].value;
  }  else var action = "calculate_qty";
  url = "common.pl?" +
    "action=" + action + "&" +
    "login=" + encodeURIComponent(document.getElementsByName("login")[0].value) + "&" +
    "password=" + encodeURIComponent(document.getElementsByName("password")[0].value) + "&" +
    "path=" + encodeURIComponent(document.getElementsByName("path")[0].value) + "&" +
    "name=" + escape(name) + "&" +
    "input_name=" + escape(input_name) + "&" +
    "description=" + escape(description) + "&" +
    "qty=" + escape(qty) + "&" +
    "row=" + escape(row) + "&" +
   "formel=" + escape(document.getElementsByName(formel)[0].value)
  //alert(url);
  window.open(url, "_new_generic", parm);
}
