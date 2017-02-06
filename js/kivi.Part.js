namespace('kivi.Part', function(ns) {
  'use strict';

  ns.open_history_popup = function() {
    var id = $("#part_id").val();
    kivi.popup_dialog({
      url:    'controller.pl?action=Part/history&part.id=' + id,
      dialog: { title: kivi.t8('History') },
    });
  }

  ns.save = function() {
    var data = $('#ic').serializeArray();
    data.push({ name: 'action', value: 'Part/save' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.use_as_new = function() {
    var oldid = $("#part_id").val();
    $('#ic').attr('action', 'controller.pl?action=Part/use_as_new&old_id=' + oldid);
    $('#ic').submit();
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

  ns.reorder_items = function(order_by) {
    var dir = $('#' + order_by + '_header_id a img').attr("data-sort-dir");
    var part_type = $("#part_part_type").val();

    var data;
    if (part_type === 'assortment') {
      $('#assortment thead a img').remove();
      data = $('#assortment :input').serializeArray();
    } else if ( part_type === 'assembly') {
      $('#assembly thead a img').remove();
      data = $('#assembly :input').serializeArray();
    }

    var src;
    if (dir == "1") {
      dir = "0";
      src = "image/up.png";
    } else {
      dir = "1";
      src = "image/down.png";
    }

    $('#' + order_by + '_header_id a').append('<img border=0 data-sort-dir=' + dir + ' src=' + src + ' alt="' + kivi.t8('sort items') + '">');

    data.push({ name: 'action',    value: 'Part/reorder_items' },
              { name: 'order_by',  value: order_by             },
              { name: 'part_type', value: part_type            },
              { name: 'sort_dir',  value: dir                  });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assortment_recalc = function() {
    var data = $('#assortment :input').serializeArray();
    data.push({ name: 'action', value: 'Part/update_item_totals' },
              { name: 'part_type', value: 'assortment'                   });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assembly_recalc = function() {
    var data = $('#assembly :input').serializeArray();
    data.push( { name: 'action',    value: 'Part/update_item_totals' },
               { name: 'part_type', value: 'assembly'                        });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.set_assortment_sellprice = function() {
    $("#part_sellprice_as_number").val($("#items_sellprice_sum").html());
    // ns.set_tab_active_by_name('basic_data');
    // $("#part_sellprice_as_number").focus();
  };

  ns.set_assortment_lsg_sellprice = function() {
    $("#items_lsg_sellprice_sum_basic").closest('td').find('input').val($("#items_lsg_sellprice_sum").html());
  };

  ns.set_assortment_douglas_sellprice = function() {
    $("#items_douglas_sellprice_sum_basic").closest('td').find('input').val($("#items_douglas_sellprice_sum").html());
  };

  ns.set_assortment_lastcost = function() {
    $("#part_lastcost_as_number").val($("#items_lastcost_sum").html());
    // ns.set_tab_active_by_name('basic_data');
    // $("#part_lastcost_as_number").focus();
  };

  ns.set_assembly_sellprice = function() {
    $("#part_sellprice_as_number").val($("#items_sellprice_sum").html());
    // ns.set_tab_active_by_name('basic_data');
    // $("#part_sellprice_as_number").focus();
  };

  ns.renumber_positions = function() {
    var part_type = $("#part_part_type").val();
    var rows;
    if (part_type === 'assortment') {
      rows = $('.assortment_item_row [name="position"]');
    } else if ( part_type === 'assembly') {
      rows = $('.assembly_item_row [name="position"]');
    }
    $(rows).each(function(idx, elt) {
      $(elt).html(idx+1);
      var row = $(elt).closest('tr');
      if ( idx % 2 === 0 ) {
        if ( row.hasClass('listrow1') ) {
          row.removeClass('listrow1');
          row.addClass('listrow0');
        }
      } else {
        if ( row.hasClass('listrow0') ) {
          row.removeClass('listrow0');
          row.addClass('listrow1');
        }
      }
    });
  };

  ns.delete_item_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();
    var part_type = $("#part_part_type").val();
    ns.renumber_positions();
    if (part_type === 'assortment') {
      ns.assortment_recalc();
    } else if ( part_type === 'assembly') {
      ns.assembly_recalc();
    }
  };

  ns.add_assortment_item = function() {
    if ($('#add_assortment_item_id').val() === '') return;

    $('#row_table_id thead a img').remove();

    var data = $('#assortment :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_assortment_item' },
              { name: 'part.id', value: $('#part_id').val()       },
              { name: 'part.part_type', value: 'assortment'       });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.add_assembly_item = function() {
    if ($('#add_assembly_item_id').val() === '') return;

    var data = $('#assembly :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_assembly_item' },
              { name: 'part.id', value: $("#part_id").val()     },
              { name: 'part.part_type', value: 'assortment'     });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.redisplay_items = function(data) {
    var old_rows;
    var part_type = $("#part_part_type").val();
    if (part_type === 'assortment') {
      old_rows = $('.assortment_item_row').detach();
    } else if ( part_type === 'assembly') {
      old_rows = $('.assembly_item_row').detach();
    }
    var new_rows = [];
    $(data).each(function(idx, elt) {
      new_rows.push(old_rows[elt.old_pos - 1]);
    });
    if (part_type === 'assortment') {
      $(new_rows).appendTo($('#assortment_items'));
    } else if ( part_type === 'assembly') {
      $(new_rows).appendTo($('#assembly_items'));
    }
    ns.renumber_positions();
  };

  ns.focus_last_assortment_input = function () {
    $("#assortment_items tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  ns.focus_last_assembly_input = function () {
    $("#assembly_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  ns.show_multi_items_dialog = function(part_type,part_id) {

    $('#row_table_id thead a img').remove();

    kivi.popup_dialog({
      url: 'controller.pl?action=Part/show_multi_items_dialog',
      data: { callback:         'Part/add_multi_' + part_type + '_items',
              callback_data_id: 'ic',
              'part.part_type': part_type,
              'part.id'       : part_id,
            },
      id: 'jq_multi_items_dialog',
      dialog: {
        title: kivi.t8('Add multiple items'),
        width:  800,
        height: 800
      }
    });
    return true;
  };

  ns.close_multi_items_dialog = function() {
    $('#jq_multi_items_dialog').dialog('close');
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

  var KEY = {
    TAB:       9,
    ENTER:     13,
    SHIFT:     16,
    CTRL:      17,
    ALT:       18,
    ESCAPE:    27,
    PAGE_UP:   33,
    PAGE_DOWN: 34,
    LEFT:      37,
    UP:        38,
    RIGHT:     39,
    DOWN:      40,
  };

  ns.Picker = function($real, options) {
    // short circuit in case someone double inits us
    if ($real.data("part_picker"))
      return $real.data("part_picker");

    var CLASSES = {
      PICKED:       'partpicker-picked',
      UNDEFINED:    'partpicker-undefined',
      FAT_SET_ITEM: 'partpicker_fat_set_item',
    };
    var o = $.extend({
      limit: 20,
      delay: 50,
      fat_set_item: $real.hasClass(CLASSES.FAT_SET_ITEM),
      action: {
        on_enter_match_none: function(){ },
        on_enter_match_one:  function(){ $('#update_button').click(); },
        on_enter_match_many: function(){ open_dialog(); }
      }
    }, options);
    var STATES = {
      PICKED:    CLASSES.PICKED,
      UNDEFINED: CLASSES.UNDEFINED
    }
    var real_id = $real.attr('id');
    var $dummy             = $('#' + real_id + '_name');
    var $part_type         = $('#' + real_id + '_part_type');
    var $classification_id = $('#' + real_id + '_classification_id');
    var $unit              = $('#' + real_id + '_unit');
    var $convertible_unit  = $('#' + real_id + '_convertible_unit');
    var autocomplete_open  = false;
    var state   = STATES.PICKED;
    var last_real = $real.val();
    var last_dummy = $dummy.val();
    var timer;

    function ajax_data(term) {
      var data = {
        'filter.all:substr:multi::ilike': term,
        'filter.obsolete': 0,
        'filter.unit_obj.convertible_to': $convertible_unit && $convertible_unit.val() ? $convertible_unit.val() : '',
        current:  $real.val(),
      };

      if ($part_type && $part_type.val())
        data['filter.part_type'] = $part_type.val().split(',');

      if ($classification_id && $classification_id.val())
        data['filter.classification_id'] = $classification_id.val().split(',');

      if ($unit && $unit.val())
        data['filter.unit'] = $unit.val().split(',');

      return data;
    }

    function set_item (item) {
      if (item.id) {
        $real.val(item.id);
        // autocomplete ui has name, use the value for ajax items, which contains displayable_name
        $dummy.val(item.name ? item.name : item.value);
      } else {
        $real.val('');
        $dummy.val('');
      }
      state      = STATES.PICKED;
      last_real  = $real.val();
      last_dummy = $dummy.val();
      $real.trigger('change');

      if (o.fat_set_item && item.id) {
        $.ajax({
          url: 'controller.pl?action=Part/show.json',
          data: { 'part.id': item.id },
          success: function(rsp) {
            $real.trigger('set_item:PartPicker', rsp);
          },
        });
      } else {
        $real.trigger('set_item:PartPicker', item);
      }
      annotate_state();
    }

    function make_defined_state () {
      if (state == STATES.PICKED) {
        annotate_state();
        return true
      } else if (state == STATES.UNDEFINED && $dummy.val() === '')
        set_item({})
      else {
        set_item({ id: last_real, name: last_dummy })
      }
      annotate_state();
    }

    function annotate_state () {
      if (state == STATES.PICKED)
        $dummy.removeClass(STATES.UNDEFINED).addClass(STATES.PICKED);
      else if (state == STATES.UNDEFINED && $dummy.val() === '')
        $dummy.removeClass(STATES.UNDEFINED).addClass(STATES.PICKED);
      else {
        $dummy.addClass(STATES.UNDEFINED).removeClass(STATES.PICKED);
      }
    }

    function handle_changed_text(callbacks) {
      $.ajax({
        url: 'controller.pl?action=Part/ajax_autocomplete',
        dataType: "json",
        data: $.extend( ajax_data($dummy.val()), { prefer_exact: 1 } ),
        success: function (data) {
          if (data.length == 1) {
            set_item(data[0]);
            if (callbacks && callbacks.match_one) callbacks.match_one(data[0]);
          } else if (data.length > 1) {
            state = STATES.UNDEFINED;
            if (callbacks && callbacks.match_many) callbacks.match_many(data);
          } else {
            state = STATES.UNDEFINED;
            if (callbacks && callbacks.match_none) callbacks.match_none();
          }
          annotate_state();
        }
      });
    }

    function open_dialog() {
      // TODO: take the actual object here
      var dialog = new ns.PickerPopup({
        ajax_data: ajax_data,
        real_id: real_id,
        dummy: $dummy,
        real: $real,
        set_item: set_item
      });
    }

    $dummy.autocomplete({
      source: function(req, rsp) {
        $.ajax($.extend(o, {
          url:      'controller.pl?action=Part/ajax_autocomplete',
          dataType: "json",
          data:     ajax_data(req.term),
          success:  function (data){ rsp(data) }
        }));
      },
      select: function(event, ui) {
        set_item(ui.item);
      },
      search: function(event, ui) {
        if ((event.which == KEY.SHIFT) || (event.which == KEY.CTRL) || (event.which == KEY.ALT))
          event.preventDefault();
      },
      open: function() {
        autocomplete_open = true;
      },
      close: function() {
        autocomplete_open = false;
      }
    });
    /*  In case users are impatient and want to skip ahead:
     *  Capture <enter> key events and check if it's a unique hit.
     *  If it is, go ahead and assume it was selected. If it wasn't don't do
     *  anything so that autocompletion kicks in.  For <tab> don't prevent
     *  propagation. It would be nice to catch it, but javascript is too stupid
     *  to fire a tab event later on, so we'd have to reimplement the "find
     *  next active element in tabindex order and focus it".
     */
    /* note:
     *  event.which does not contain tab events in keypressed in firefox but will report 0
     *  chrome does not fire keypressed at all on tab or escape
     */
    $dummy.keydown(function(event){
      if (event.which == KEY.ENTER || event.which == KEY.TAB) {
        // if string is empty assume they want to delete
        if ($dummy.val() === '') {
          set_item({});
          return true;
        } else if (state == STATES.PICKED) {
          return true;
        }
        if (event.which == KEY.TAB) {
          event.preventDefault();
          handle_changed_text();
        }
        if (event.which == KEY.ENTER) {
          handle_changed_text({
            match_one:  o.action.on_enter_match_one,
            match_many: o.action.on_enter_match_many
          });
          return false;
        }
      } else if (event.which == KEY.DOWN && !autocomplete_open) {
        var old_options = $dummy.autocomplete('option');
        $dummy.autocomplete('option', 'minLength', 0);
        $dummy.autocomplete('search', $dummy.val());
        $dummy.autocomplete('option', 'minLength', old_options.minLength);
      } else if ((event.which != KEY.SHIFT) && (event.which != KEY.CTRL) && (event.which != KEY.ALT)) {
        state = STATES.UNDEFINED;
      }
    });

    $dummy.on('paste', function(){
      setTimeout(function() {
        handle_changed_text();
      }, 1);
    });

    $dummy.blur(function(){
      window.clearTimeout(timer);
      timer = window.setTimeout(annotate_state, 100);
    });

    // now add a picker div after the original input
    var popup_button = $('<span>').addClass('ppp_popup_button');
    $dummy.after(popup_button);
    popup_button.click(open_dialog);

    var pp = {
      real:              function() { return $real },
      dummy:             function() { return $dummy },
      part_type:         function() { return $part_type },
      classification_id: function() { return $classification_id },
      unit:              function() { return $unit },
      convertible_unit:  function() { return $convertible_unit },
      set_item:       set_item,
      reset:          make_defined_state,
      is_defined_state: function() { return state == STATES.PICKED },
    }
    $real.data('part_picker', pp);
    return pp;
  };

  ns.PickerPopup = function(pp) {
    this.timer = undefined;
    this.pp    = pp;
    this.open_dialog();
  };

  ns.PickerPopup.prototype = {
    open_dialog: function() {
      var self = this;
      kivi.popup_dialog({
        url: 'controller.pl?action=Part/part_picker_search',
        data: $.extend({
          real_id: self.pp.real_id,
        }, self.pp.ajax_data(this.pp.dummy.val())),
        id: 'part_selection',
        dialog: {
          title: kivi.t8('Part picker'),
          width: 800,
          height: 800,
        },
        load: function() { self.init_search(); }
      });
      window.clearTimeout(this.timer);
      return true;
    },
    init_search: function() {
      var self = this;
      $('#part_picker_filter').keypress(function(e) { self.result_timer(e) }).focus();
      $('#no_paginate').change(function() { self.update_results() });
      this.update_results();
    },
    update_results: function() {
      var self = this;
      $.ajax({
        url: 'controller.pl?action=Part/part_picker_result',
        data: $.extend({
         'real_id':    self.pp.real.val(),
          no_paginate: $('#no_paginate').prop('checked') ? 1 : 0,
        }, self.pp.ajax_data(function(){
          var val = $('#part_picker_filter').val();
          return val === undefined ? '' : val
        })),
        success: function(data){
          $('#part_picker_result').html(data);
          self.init_results();
        }
      });
    },
    init_results: function() {
      var self = this;
      $('div.part_picker_part').each(function(){
        $(this).click(function(){
          self.pp.set_item({
            id:   $(this).children('input.part_picker_id').val(),
            name: $(this).children('input.part_picker_description').val(),
            classification_id: $(this).children('input.part_picker_classification_id').val(),
            unit: $(this).children('input.part_picker_unit').val(),
            partnumber:  $(this).children('input.part_picker_partnumber').val(),
            description: $(this).children('input.part_picker_description').val(),
          });
          self.close_popup();
          self.pp.dummy.focus();
          return true;
        });
      });
      $('#part_selection').keydown(function(e){
         if (e.which == KEY.ESCAPE) {
           self.close_popup();
           self.pp.dummy.focus();
         }
      });
    },
    result_timer: function(event) {
      var self = this;
      if (!$('no_paginate').prop('checked')) {
        if (event.keyCode == KEY.PAGE_UP) {
          $('#part_picker_result a.paginate-prev').click();
          return;
        }
        if (event.keyCode == KEY.PAGE_DOWN) {
          $('#part_picker_result a.paginate-next').click();
          return;
        }
      }
      window.clearTimeout(this.timer);
      if (event.which == KEY.ENTER) {
        self.update_results();
      } else {
        this.timer = window.setTimeout(function() { self.update_results() }, 100);
      }
    },
    close_popup: function() {
      $('#part_selection').dialog('close');
    }
  };

  ns.reinit_widgets = function() {
    kivi.run_once_for('input.part_autocomplete', 'part_picker', function(elt) {
      kivi.Part.Picker($(elt));
    });
  }

  ns.init = function() {
    ns.reinit_widgets();
  }

  $(function(){

    // assortment
    // TODO: allow units for assortment items
    $('#add_assortment_item_id').on('set_item:PartPicker', function(e,o) { $('#add_item_unit').val(o.unit) });

    $('#ic').on('focusout', '.reformat_number', function(event) {
       ns.reformat_number(event);
    })

    $('.add_assortment_item_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        if ($("input[name='add_items[+].parts_id']").val() !== '' ) {
          kivi.Part.show_multi_items_dialog("assortment");
         // ns.add_assortment_item();
        }
        return false;
      }
    });

    $('.add_assembly_item_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        if ($("input[name='add_items[+].parts_id']").val() !== '' ) {
          kivi.Part.show_multi_items_dialog("assortment");
          // ns.add_assembly_item();
        }
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

    ns.init();
  });
});
