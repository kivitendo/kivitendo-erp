namespace('kivi.Warehouse', function(ns) {

  ns.wh_changed = function(target) {
    const wh_id        = $(target).val();
    const bin_dom_name = $(target).data('bin-dom-name');
    const bin_dom_id   = $(target).data('bin-dom-id');
    $.post("controller.pl", { action:       'Warehouse/wh_bin_select_update_bins',
                              wh_id:        wh_id,
                              bin_dom_id:   bin_dom_id },
           kivi.eval_json_result);
  };

  ns.wh_bin_select_update_bins = function(bin_dom_id, bins) {
    const $bin_select = $('#' + bin_dom_id);
    $bin_select.empty();
    $.each(bins, function(idx, elt) {
      $bin_select.append($('<option/>', {value: elt.key, text: elt.value}));
    });
  };

});
