namespace('kivi.StockCounting', function(ns) {

  ns.count_window_onload = () => {
    if ($('#successfully_counted').val() === '1') {
      $('#successfully_counted_modal').modal('open');
    }
    if ($('#errors').val() !== '0') {
      $('#error_modal').modal('open');
    }
  };

});
