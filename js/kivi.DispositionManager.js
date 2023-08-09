namespace('kivi.DispositionManager', function(ns) {
  ns.sort_vendors = function() {
    ns.display_vendor_parts($('#vendor_id').val());
    $("#basket_items tr").each(function(_index) {
      if(
        $(this).find("select[name='vendor_ids[]']").val() != $('#vendor_id').val()
        && $('#vendor_id').val() != ''
      ) {
        $(this).find("[name='ids[+]']").prop("checked", false);
        this.style.display = "none";
      } else {
        this.style.removeProperty('display');
      }
    });
  }

  ns.display_vendor_parts = function(vendor_id) {
    var url = 'controller.pl?action=DispositionManager/show_vendor_items&v_id=' + vendor_id;
    $('#vendor_parts').load(url);
  }

  ns.create_purchase_order = function() {
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

$(function() {
 $('#vendor_id').change('set_item:CustomerVendorPicker', function(_e,_o) {
   kivi.DispositionManager.sort_vendors();
 })
});
