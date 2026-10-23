namespace('kivi.StockDialog', function(ns) {
  ns.stock_in_out_dialog_row_by_id = function(id) {
    var $row = $("#row_table_id .row_entry").eq(id).find("tr").first().find("td").first();
    return $row;
  };

  ns.next_stock_in_out_dialog = function(id) {
    ns.save_updated_stock(false);

    var $row = ns.stock_in_out_dialog_row_by_id(id);
    var in_out = $("#stock_in_out_dialog").find("[name$=in_out]").val();

    if ($row.length != 0)
      ns.open_stock_in_out_dialog($row, in_out);
  };

  ns.open_stock_in_out_dialog = function(clicked, in_out) {
    var $row = $(clicked).parents("tbody").first();
    var id = $row.find('[name="orderitem_ids[+]"]').val();
    $row.uniqueId();

    var pos = $(clicked).parents('.row_entry').find('tr td div[name="position"]').text();

    var $next_row = ns.stock_in_out_dialog_row_by_id(pos);
    var next_button = ($next_row.length != 0);

    kivi.popup_dialog({
      id: "stock_in_out_dialog",
      url: "controller.pl?action=StockDialog/stock_in_out_dialog",
      data: {
        id:            $("#id").val(),
        type:          $("#type").val(),
        parts_id:      $row.find("[name$=parts_id]").val(),
        unit:          $row.find("[name$=unit]").val(),
        qty_as_number: $row.find("[name$=qty_as_number]").val(),
        stock:         $row.find("[name$=stock_info]").val(),
        item_id:       id,
        row:           $row.attr("id"),
        row_ui_id:     pos,
        next_button:   next_button,
      },
      dialog: { title: kivi.t8('Transfer stock') },
      load: function () {
        kivi.reinit_widgets(); // required to render L.date_tag("bestbefore", ...)
      }
    });
  };

  ns.add_stock_in_line_to_dialog = function() {
    let qty_sum = 0;
    let row_count = 0;
    $("#stock-in-out-table tr.data-row").each((i,row) => {
      let qty = kivi.parse_amount($(row).find(".data-qty").val());

      row_count = row_count + 1;
      if (qty === 0) return;
      if (qty === null) return;
      qty_sum = qty_sum + qty;
    });

    let data = [];
    data.push(
      { name: 'action', value: 'StockDialog/add_stock_in_line_to_dialog' },
      { name: 'type', value: $("#type").val()},
      { name: 'qty_sum', value: qty_sum },
      { name: 'row_count', value: row_count},
      { name: 'parts_id', value: $("#parts_id").val()},
      { name: 'do_qty', value:  $("#do_qty").val()},
    );

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.save_updated_stock = function(close_dialog) {
    // stock information is saved in DOM as a yaml dump.
    // we don't want to do this in javascript so we do a tiny roundtrip to the backend

    let data = [];
    $("#stock-in-out-table tr.data-row").each((i,row) => {
      let qty = kivi.parse_amount($(row).find(".data-qty").val());

      if (qty === 0 || qty === null) return;

      data.push({
        qty:                           qty,
        warehouse_id:                  $(row).find(".data-warehouse-id").val(),
        bin_id:                        $(row).find(".data-bin-id").val(),
        chargenumber:                  $(row).find(".data-chargenumber").val(),
        bestbefore:                    $(row).find(".data-bestbefore").val(),
        unit:                          $(row).find(".data-unit").val(),
        delivery_order_items_stock_id: $(row).find(".data-stock-id").val(),
      });
    });

    let row = $(".data-row").val();

    $.post("controller.pl",
      kivi.serialize({
        action:     "StockDialog/update_stock_information",
        unit:       $("#" + row).find("[name$=unit]").val(),
        stock_info: data,
        row:        row
      }),
      (data) => {
        $("#" + row + " .data-stock-info").val(data.stock_info);
        $("#" + row + " .data-stock-qty").text(data.stock_qty)
        if (close_dialog) {
          $("#stock_in_out_dialog").dialog("close");
        }
      }
    );
  };
});
