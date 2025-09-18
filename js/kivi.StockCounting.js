namespace('kivi.StockCounting', function(ns) {
  ns.count_window_onload = () => {
    if ($('#successfully_counted').val() === '1') {
      $('#successfully_counted_modal').modal('open');
    }
    if ($('#errors').val() !== '0') {
      $('#error_modal').modal('open');
    }
  };

  ns.submit_count = function() {
    let data = $('#count_form').serializeArray();
    data.push({name: 'action', value: 'StockCounting/count'});
    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.show_parts_in_bin = function() {
   let data = $('#count_form').serializeArray();
   data.push({name: 'action', value: 'StockCounting/show_parts_in_bin'});
   $.post("controller.pl", data, kivi.eval_json_result);
  };
});
