namespace('kivi.Warehouse', function(ns) {

  ns.wh_changed = function(target) {
    const wh_id        = $(target).val();
    const bin_dom_id   = $(target).data('bin-dom-id');
    const bin_id       = $('#' + bin_dom_id).val();

    $.post("controller.pl", { action:       'Warehouse/wh_bin_select_update_bins',
                              wh_id:        wh_id,
                              bin_id:       bin_id,
                              bin_dom_id:   bin_dom_id },
           kivi.eval_json_result);
  };

  ns.wh_bin_select_update_bins = function(bin_dom_id, bins, selected_bin) {
    const $bin_select = $('#' + bin_dom_id);
    $bin_select.empty();

    $.each(bins, function(idx, elt) {
      if (elt.key == selected_bin) {
        $bin_select.append($('<option/>', {value: elt.key, text: elt.value, selected: 1}));
      } else {
        $bin_select.append($('<option/>', {value: elt.key, text: elt.value}));
      }
    });
  };

  $(function(){
    $('.wh-bin-select-presenter-wh').each(function(idx, elt) {
      ns.wh_changed(elt);
    });
  });

});
