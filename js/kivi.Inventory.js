namespace('kivi.Inventory', function(ns) {
  ns.reload_bin_selection = function() {
    $.post("controller.pl", { action: 'Inventory/warehouse_changed',
                              warehouse_id: function(){ return $('#warehouse_id').val() } },
           kivi.eval_json_result);
  };

  ns.save_stocktaking = function(dont_check_already_counted) {
    var data = $('#stocktaking_form').serializeArray();
    data.push({ name: 'action', value: 'Inventory/save_stocktaking' });
    data.push({ name: 'dont_check_already_counted', value: dont_check_already_counted });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.stocktaking_part_changed = function() {
    var data = $('#stocktaking_form').serializeArray();
    data.push({ name: 'action', value: 'Inventory/stocktaking_part_changed' });
    $.post("controller.pl", data, kivi.eval_json_result);
    $.post("controller.pl", { action: 'Inventory/mini_stock',
                              part_id: function(){ return $('#part_id').val() } },
           kivi.eval_json_result);
  };

  ns.reload_stocktaking_history = function(target, source) {
    var data = $('#stocktaking_form').serializeArray();
    $.ajax({
      url:        source,
      data:       data,
      success:    function (rsp) {
        $(target).html(rsp);
        $(target).find('a.paginate-link').click(function(event){
          event.preventDefault();
          kivi.Inventory.reload_stocktaking_history(target, event.target + '')});
      }
    });
  };

  ns.stocktaking_correct_counted = function() {
    kivi.Inventory.close_already_counted_dialog();
    kivi.Inventory.save_stocktaking(1);
  };

  ns.stocktaking_add_counted = function(qty_to_add_to) {
    resulting_qty = kivi.parse_amount($('#target_qty').val()) + 1.0*qty_to_add_to;
    $('#target_qty').val(kivi.format_amount(resulting_qty, -2));
    kivi.Inventory.close_already_counted_dialog();
    kivi.Inventory.save_stocktaking(1);
  };

  ns.close_already_counted_dialog = function() {
    $('#already_counted_dialog').dialog("close");
  };

});

$(function(){
  $('#part_id').change(kivi.Inventory.stocktaking_part_changed);
  $('#warehouse_id').change(kivi.Inventory.reload_bin_selection);
  $('#cutoff_date_as_date').change(function() {kivi.Inventory.reload_stocktaking_history('#stocktaking_history', 'controller.pl?action=Inventory/reload_stocktaking_history');});

  kivi.Inventory.reload_stocktaking_history('#stocktaking_history', 'controller.pl?action=Inventory/reload_stocktaking_history');
});
