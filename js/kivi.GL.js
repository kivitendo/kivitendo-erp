namespace('kivi.GL', function(ns) {
  "use strict";

  this.show_chart_balance = function(obj) {
    var row = $(obj).attr('name').replace(/.*_/, '');

    $.ajax({
      url: 'gl.pl?action=get_chart_balance',
      data: { accno_id:  $(obj).val() },
      dataType: 'html',
      success: function (new_html) {
        $('#chart_balance_' + row).html(new_html);
      }
    });
  };

  this.update_taxes = function(obj) {
    var row = $(obj).attr('name').replace(/.*_/, '');

    $.ajax({
      url: 'gl.pl?action=get_tax_dropdown',
      data: { accno_id:     $(obj).val(),
              transdate:    $('#transdate').val(),
              deliverydate: $('#deliverydate').val() },
      dataType: 'html',
      success: function (new_html) {
        $("#taxchart_" + row).html(new_html);
      }
    });
  };
});
