namespace('kivi.Part', function(ns) {

  ns.save = function() {
    var data = $('#ic').serializeArray();
    data.push({ name: 'action', value: 'Part/save' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.save_as_new = function() {
    var data = $('#ic').serializeArray();
    data.push({ name: 'action', value: 'Part/save_as_new' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.delete = function() {
    var data = $('#ic').serializeArray();
    data.push({ name: 'action', value: 'Part/delete' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.reformat_number = function(event) {
    $(event.target).val(kivi.format_amount(kivi.parse_amount($(event.target).val()), -2));
  };

  ns.set_tab_active_by_index = function (index) {
    $("#ic_tabs").tabs({active: index})
  };

  ns.set_tab_active_by_name= function (name) {
    var index = $('#ic_tabs a[href=#' + name + ']').parent().index();
    ns.set_tab_active_by_index(index);
  };


  // assortment
  ns.assortment_reorder_items = function(order_by) {
    var dir = $('#' + order_by + '_header_id a img').attr("data-sort-dir");

    var src;
    if (dir == "1") {
      dir = "0";
      src = "image/up.png";
    } else {
      dir = "1";
      src = "image/down.png";
    }

    $('#' + order_by + '_header_id a').append('<img border=0 data-sort-dir=' + dir + ' src=' + src + ' alt="' + kivi.t8('sort items') + '">');

    var data = $('#assortment :input').serializeArray();
    data.push({ name: 'action', value: 'Part/reorder_assortment_items' });
    data.push({ name: 'order_by', value: order_by });
    data.push({ name: 'sort_dir', value: dir });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assortment_recalc = function() {
    var data = $('#assortment :input').serializeArray();
    data.push({ name: 'action', value: 'Part/assortment_update' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.set_assortment_sellprice = function() {
    console.log("setting sellprice to " + $("#assortment_sum").html());
    $("#part_sellprice_as_number").val($("#assortment_sum").html());
    ns.set_tab_active_by_name('basic_data');
    $("#part_sellprice_as_number").focus();
  };

  ns.assortment_renumber_positions = function() {
    $('.assortment_item_row [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
      var row = $(elt).closest('tr');
      if ( idx % 2 === 0 ) {
        if ( row.hasClass('listrow1') ) {
          row.removeClass('listrow1');
          row.addClass('listrow0');
        };
      } else {
        if ( row.hasClass('listrow0') ) {
          row.removeClass('listrow0');
          row.addClass('listrow1');
        };
      };
    });
  };

  ns.delete_assortment_item_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();

    ns.assortment_renumber_positions();
    ns.assortment_recalc();
  };

  ns.add_assortment_item = function() {
    if ($('#add_assortment_item_id').val() === '') return;

    $('#row_table_id thead a img').remove();

    var data = $('#assortment :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_assortment_item' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.redisplay_assortment_items = function(data) {
    var old_rows = $('.assortment_item_row').detach();
    var new_rows = [];
    $(data).each(function(idx, elt) {
      new_rows.push(old_rows[elt.old_pos - 1]);
    });
    $(new_rows).appendTo($('#assortment_items'));
    ns.assortment_renumber_positions();
  };

  ns.focus_last_assortment_input = function () {
    $("#assortment_items tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  // assembly
  ns.assembly_reorder_items = function(order_by) {
    var dir = $('#' + order_by + '_header_id a img').attr("data-sort-dir");
    $('#assembly_items thead a img').remove();

    var src;
    if (dir == "1") {
      dir = "0";
      src = "image/up.png";
    } else {
      dir = "1";
      src = "image/down.png";
    }

    $('#' + order_by + '_header_id a').append('<img border=0 data-sort-dir=' + dir + ' src=' + src + ' alt="' + kivi.t8('sort items') + '">');

    var data = $('#assembly :input').serializeArray();
    data.push({ name: 'action', value: 'Part/reorder_assembly_items' });
    data.push({ name: 'order_by', value: order_by });
    data.push({ name: 'sort_dir', value: dir });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assembly_recalc = function() {
    var data = $('#assembly :input').serializeArray();
    data.push( { name: 'action', value: 'Part/assembly_update' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.set_assembly_sellprice = function() {
    console.log("setting sellprice to " + $("#assembly_sum").html());
    $("#part_sellprice_as_number").val($("#assembly_sum").html());
    ns.set_tab_active_by_name('basic_data');
    $("#part_sellprice_as_number").focus();
  };

  ns.assembly_renumber_positions = function() {
    $('.assembly_item_row [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
      var row = $(elt).closest('tr');
      if ( idx % 2 === 0 ) {
        if ( row.hasClass('listrow1') ) {
          row.removeClass('listrow1');
          row.addClass('listrow0');
        };
      } else {
        if ( row.hasClass('listrow0') ) {
          row.removeClass('listrow0');
          row.addClass('listrow1');
        };
      };
    });
  };


  ns.delete_assembly_item_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();

    ns.assembly_renumber_positions();
    ns.assembly_recalc();
  };

  ns.add_assembly_item = function() {
    if ($('#add_assembly_item_id').val() === '') return;

    var data = $('#assembly :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_assembly_item' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.redisplay_assembly_items = function(data) {
    var old_rows = $('.assembly_item_row').detach();
    var new_rows = [];
    $(data).each(function(idx, elt) {
      new_rows.push(old_rows[elt.old_pos - 1]);
    });
    $(new_rows).appendTo($('#assembly_items'));
    ns.assembly_renumber_positions();
  };

  ns.focus_last_assembly_input = function () {
    $("#assembly_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  // makemodel
  ns.makemodel_renumber_positions = function() {
    $('.makemodel_row [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
    });
  };

  ns.delete_makemodel_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();

    ns.makemodel_renumber_positions();
  };

  ns.add_makemodel_row = function() {
    if ($('#add_makemodelid').val() === '') return;

    var data = $('#makemodel_table :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_makemodel_row' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.focus_last_makemodel_input = function () {
    $("#makemodel_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };


  ns.reload_bin_selection = function() {
    $.post("controller.pl", { action: 'Part/warehouse_changed', warehouse_id: function(){ return $('#part_warehouse_id').val() } },   kivi.eval_json_result);
  }

  $(function(){

    // assortment
    // TODO: allow units for assortment items
    $('#add_assortment_item_id').on('set_item:PartPicker', function(e,o) { $('#add_item_unit').val(o.unit) });

    $('#ic').on('focusout', '.reformat_number', function(event) {
       ns.reformat_number(event);
    })

    // if there is exactly one item recommendation in part_picker, and user presses enter, add the item
    $('.add_assortment_item_input').keydown(function(event) {
      console.log('keydown');
      if(event.keyCode == 13) {
        event.preventDefault();
        // console.log('id = ' + $('#add_assortment_item'));
        ns.add_assortment_item();
        return false;
      }
    });
    $('.add_assembly_item_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        ns.add_assembly_item();
        return false;
      }
    });
    $('.add_makemodel_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        ns.add_makemodel_row();
        return false;
      }
    });

    $('#part_warehouse_id').change(kivi.Part.reload_bin_selection);

  });
})
