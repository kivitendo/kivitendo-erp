namespace('kivi.DispositionManager', function(ns) {
  ns.sort_vendors = function() {
    ns.display_vendor_parts($('#vendor_id2').val());
    $("tbody tr").each(function(index) {
      if ( index !== 0 ) {
        $row = $(this);
        if( $row.find("select[name='vendor_ids[]']").val() != $('#vendor_id2').val()) {
          $row.remove();
        }
      }
    });
  }

  ns.display_vendor_parts = function(vendor_id) {
    var url = 'controller.pl?action=DispositionManager/show_vendor_items&v_id=' + vendor_id;
    $('#vendor_parts').load(url);
  }

  ns.create_order = function() {
    var data = $('#purchasebasket').serializeArray();
    data.push({ name: 'action', value: 'DispositionManager/transfer_to_purchase_order' });
    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.delete_purchase_basket_items = function() {
    var data = $('#purchasebasket').serializeArray();
    data.push({
      name:  'action',
      value: 'DispositionManager/delete_purchase_basket_items' });
    $.post("controller.pl", data, kivi.eval_json_result);
  }

  ns.show_detail_dialog = function(part_id,partnumber) {
    if ( part_id && partnumber ) {
        var title  = kivi.t8('Details of article number "#1"',[partnumber]);
        kivi.popup_dialog({
                         url:     'controller.pl',
                         data: {
                                 action: 'Part/showdetails',
                                 id    : part_id,
                               },
                         id:     'detail_menu',
                         dialog: { title: title
                                  , width:  1000
                                  , height: 450
                                  , modal:  false }
                        });
    }
    return true;
  };
});
