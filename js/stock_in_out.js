function open_stock_in_out_window(in_out, row) {
  var width     = 980;
  var height    = 600;
  var parm      = centerParms(width, height) + ",width=" + width + ",height=" + height + ",status=yes,scrollbars=yes";

  var parts_id  = document.getElementsByName("id_" + row)[0].value;
  var stock     = document.getElementsByName("stock_" + in_out + "_" + row)[0].value;
  var do_qty    = document.getElementsByName("qty_" + row)[0].value;
  var do_unit   = document.getElementsByName("unit_" + row)[0].value;
  var closed    = document.getElementsByName("closed")[0].value;
  var delivered = document.getElementsByName("delivered")[0].value;

  url = "do.pl?" +
    "INPUT_ENCODING=UTF-8&" +
    "action=stock_in_out_form&" +
    "in_out="    + encodeURIComponent(in_out)    + "&" +
    "row="       + encodeURIComponent(row)       + "&" +
    "parts_id="  + encodeURIComponent(parts_id)  + "&" +
    "do_qty="    + encodeURIComponent(do_qty)    + "&" +
    "do_unit="   + encodeURIComponent(do_unit)   + "&" +
    "stock="     + encodeURIComponent(stock)     + "&" +
    "closed="    + encodeURIComponent(closed)    + "&" +
    "delivered=" + encodeURIComponent(delivered) + "&" +
    "";
  //alert(url);
  window.open(url, "_new_generic", parm);

}
