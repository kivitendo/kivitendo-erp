namespace('kivi.POS', function(ns) {
  ns.delete_order_item_row_point_of_sales = function(item_id) {
    var row = $('#item_' + item_id).parents("tbody").first();
    $(row).remove();

    $('#edit_order_item_row_point_of_sales_dialog').dialog('close');
    kivi.Order.renumber_positions();
    kivi.Order.recalc_amounts_and_taxes();
  };


  ns.edit_order_item_row_point_of_sales = function(item_id) {

    var data = $('#order_form').serializeArray();
    data.push({ name: 'item_id', value: item_id });

    kivi.popup_dialog({
      url:    'controller.pl?action=POS/edit_order_item_row_point_of_sales_dialog',
      data:   data,
      id:     'edit_order_item_row_point_of_sales_dialog',
      load:   function() {kivi.reinit_widgets(); kivi.Order.init_row_handlers() },
      dialog: {
        title:  kivi.t8('Edit row'),
        width:  800,
        height: 650
      }
    });
  };

  ns.assign_edit_order_item_row_point_of_sales = function(item_id) {
    var row = $('#item_' + item_id).parents("tbody").first();

    var discount = $('#item_discount_as_percent').val();
    $(row).find('[name="discount_as_percent"]').html(discount);
    $(row).find('[name="order.orderitems[].discount_as_percent"]').val(discount);

    // TODO
    // var salesman_id = 0;
    // $(row).find('[name="order.orderitems[].salesman_id"]');


    $('#edit_order_item_row_point_of_sales_dialog').dialog('close');
    kivi.Order.recalc_amounts_and_taxes();
  }

});
