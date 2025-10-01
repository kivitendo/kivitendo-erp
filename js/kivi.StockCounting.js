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
    alert('Bin hier');
    data.push({name: 'action', value: 'StockCounting/show_parts_in_bin'});
    $.post("controller.pl", data, kivi.eval_json_result);
  }

});
