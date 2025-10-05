namespace('kivi.StockCounting', function(ns) {

  ns.count_window_onload = () => {
    if ($('#successfully_counted').val() === '1') {
      $('#successfully_counted_modal').modal('open');
    }
    if ($('#errors').val() !== '0') {
      $('#error_modal').modal('open');
    }
  };

  ns.show_parts_in_bin = function() {
    let data = $('#count_form').serializeArray();
    data.push({name: 'action', value: 'StockCounting/show_parts_in_bin'});
    $.post("controller.pl", data, kivi.eval_json_result);
  }
});

$(function() {
  $('#stock_counting_item_bin_id').on('set_item:BinPicker', function (e, item) {
  $('#part_id_name').focus();
  kivi.StockCounting.show_parts_in_bin();
  });
  if ( $('#stock_counting_item_bin_id').val() ){
    kivi.StockCounting.show_parts_in_bin();
  }
  $("div.counted table tbody tr").click(function () {
   alert ("clicked");
  });
});
