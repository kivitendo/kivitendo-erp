namespace('kivi.Part', function(ns) {
  'use strict';

  ns.open_history_popup = function() {
    var id = $("#part_id").val();
    kivi.popup_dialog({
      url:    'controller.pl?action=Part/history&part.id=' + id,
      dialog: { title: kivi.t8('History') },
    });
  };

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

  ns.print_from_showdetail = function(part_id) {
    var data = $('#print_options_form').serializeArray();
    data.push({ name: 'action', value: 'Part/print_label' });
    data.push({ name: 'part.id', value: part_id });
  $.download("controller.pl", data);
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
    $("#ic_tabs").tabs({active: index});
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

    data.push(
      { name: 'action',    value: 'Part/reorder_items' },
      { name: 'order_by',  value: order_by             },
      { name: 'part_type', value: part_type            },
      { name: 'sort_dir',  value: dir                  }
    );

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assortment_recalc = function() {
    var data = $('#assortment :input').serializeArray();
    data.push(
      { name: 'action', value: 'Part/update_item_totals' },
      { name: 'part_type', value: 'assortment'           }
    );

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assembly_recalc = function() {
    var data = $('#assembly :input').serializeArray();
    data.push(
      { name: 'action',    value: 'Part/update_item_totals' },
      { name: 'part_type', value: 'assembly'                }
    );

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
    if ($('#assortment_picker').val() === '') return;

    $('#row_table_id thead a img').remove();

    var data = $('#assortment :input').serializeArray();
    data.push(
      { name: 'action', value: 'Part/add_assortment_item' },
      { name: 'part.id', value: $('#part_id').val()       },
      { name: 'part.part_type', value: 'assortment'       }
    );
    $('#assortment_picker').data('part_picker').clear();

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.add_assembly_item = function() {
    if ($('#assembly_picker').val() === '') return;

    var data = $('#assembly :input').serializeArray();
    data.push(
      { name: 'action', value: 'Part/add_assembly_item' },
      { name: 'part.id', value: $("#part_id").val()     },
      { name: 'part.part_type', value: 'assembly'       }
    );
    $('#assembly_picker').data('part_picker').clear();

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.set_multi_assembly_items = function(data) {
    data.push({ name: 'part.id',        value: $('#part_id').val() });
    data.push({ name: 'part.part_type', value: $('#part_part_type').val() });
    $.post("controller.pl?action=Part/add_multi_assembly_items", data, kivi.eval_json_result);
  };

  ns.set_multi_assortment_items = function(data) {
    data.push({ name: 'part.id', value: $('#part_id').val() });
    data.push({ name: 'part.part_type', value: $('#part_part_type').val() });
    $.post("controller.pl?action=Part/add_multi_assortment_items", data, kivi.eval_json_result);
  };

  ns.close_picker_dialogs = function() {
    $('.part_autocomplete').each(function(_, e) {
      var picker = $(e).data('part_picker');
      if (picker && picker.dialog) picker.close_dialog();
    });
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
    if ($('#add_makemodel').val() === '') return;

    var data = $('#makemodel_table :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_makemodel_row' });
    $('#add_makemodel').data('customer_vendor_picker').clear();

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.focus_last_makemodel_input = function () {
    $("#makemodel_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  // businessmodel
  ns.businessmodel_renumber_positions = function() {
    $('.businessmodel_row [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
    });
  };

  ns.delete_businessmodel_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();

    ns.businessmodel_renumber_positions();
  };

  ns.add_businessmodel_row = function() {
    if ($('#add_businessmodel').val() === '') return;

    var data = $('#businessmodel_table :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_businessmodel_row' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.focus_last_businessmodel_input = function () {
    $("#businessmodel_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  // customerprice
  ns.customerprice_renumber_positions = function() {
    $('.customerprice_row [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
    });
  };

  ns.delete_customerprice_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();

    ns.customerprice_renumber_positions();
  };

  ns.add_customerprice_row = function() {
    if ($('#add_customerprice').val() === '') return;

    var data = $('#customerprice_table :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_customerprice_row' });
    $('#add_customerprice').data('customer_vendor_picker').clear();

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.focus_last_customerprice_input = function () {
    $("#customerprice_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };


  ns.reload_bin_selection = function() {
    $.post("controller.pl", { action: 'Part/warehouse_changed', warehouse_id: function(){ return $('#part_warehouse_id').val(); } },   kivi.eval_json_result);
  };

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
    var self = this;
    this.o = $.extend(true, {
      limit: 20,
      delay: 50,
      action: {
        commit_none: function(){ },
        commit_one:  function(){ $('#update_button').click(); },
        commit_many: function(){ self.open_dialog(); }
      },
      multiple_limit: 100
    }, $real.data('part-picker-data'), options);
    this.$real              = $real;
    this.real_id            = $real.attr('id');
    this.last_real          = $real.val();
    this.$dummy             = $($real.siblings()[0]);
    this.autocomplete_open  = false;
    this.menu_above         = false;
    this.state              = this.STATES.PICKED;
    this.last_dummy         = this.$dummy.val();
    this.timer              = undefined;
    this.dialog             = undefined;
    this.multiple_default   = this.o.multiple;

    this.init();
  };

  ns.Picker.prototype = {
    CLASSES: {
      PICKED:       'partpicker-picked',
      UNDEFINED:    'partpicker-undefined',
    },
    ajax_data: function(term) {
      var data = {
        current:  this.$real.val(),
      };

      if (this.o.part_type)
        data['filter.part_type'] = this.o.part_type.split(',');

      if (this.o.status) {
        if (this.o.status == 'active')   data['filter.obsolete'] = 0;
        if (this.o.status == 'obsolete') data['filter.obsolete'] = 1;
      } else
        data['filter.obsolete'] = 0;

      if (this.o.classification_id)
        data['filter.classification_id:any'] = this.o.classification_id.replaceAll(',', ' ');

      if (this.o.unit)
        data['filter.unit'] = this.o.unit.split(',');

      if (this.o.convertible_unit)
        data['filter.unit_obj.convertible_to'] = this.o.convertible_unit;

      if (this.o.order_locked)
        data['filter.order_locked'] = 1;
      if (this.o.not_order_locked)
        data['filter.order_locked'] = 0;

      var filter_name = 'all';
      if (this.o.with_makemodel) {
        filter_name = 'all_with_makemodel';
      }
      if (this.o.with_customer_partnumber) {
        filter_name = 'all_with_customer_partnumber';
      }
      data['filter.' + filter_name + ':substr:multi::ilike'] = term;

      return data;
    },
    set_item: function(item) {
      var self = this;
      if (item.id) {
        this.$real.val(item.id);
        // autocomplete ui has name, use the value for ajax items, which contains displayable_name
        this.$dummy.val(item.name ? item.name : item.value);
      } else {
        this.$real.val('');
        this.$dummy.val('');
      }
      this.state      = this.STATES.PICKED;
      this.last_real  = this.$real.val();
      this.last_dummy = this.$dummy.val();
      this.$real.trigger('change');

      if (this.o.fat_set_item && item.id) {
        $.ajax({
          url: 'controller.pl?action=Part/show.json',
          data: { 'part.id': item.id },
          success: function(rsp) {
            self.$real.trigger('set_item:PartPicker', rsp);
          },
        });
      } else {
        this.$real.trigger('set_item:PartPicker', item);
      }
      this.annotate_state();
    },
    set_multi_items: function(data) {
      this.run_action(this.o.action.set_multi_items, [ data ]);
    },
    make_defined_state: function() {
      if (this.state == this.STATES.PICKED) {
        this.annotate_state();
        return true;
      } else if (this.state == this.STATES.UNDEFINED && this.$dummy.val() === '') {
        this.set_item({});
      } else {
        this.set_item({ id: this.last_real, name: this.last_dummy });
      }
      this.annotate_state();
    },
    annotate_state: function() {
      if (this.state == this.STATES.PICKED)
        this.$dummy.removeClass(this.STATES.UNDEFINED).addClass(this.STATES.PICKED);
      else if (this.state == this.STATES.UNDEFINED && this.$dummy.val() === '')
        this.$dummy.removeClass(this.STATES.UNDEFINED).addClass(this.STATES.PICKED);
      else {
        this.$dummy.addClass(this.STATES.UNDEFINED).removeClass(this.STATES.PICKED);
      }
    },
    handle_changed_text: function(callbacks) {
      var self = this;
      $.ajax({
        url: 'controller.pl?action=Part/ajax_autocomplete',
        dataType: "json",
        data: $.extend( self.ajax_data(self.$dummy.val()), { prefer_exact: 1 } ),
        success: function (data) {
          if (data.length == 1) {
            self.set_item(data[0]);
            if (callbacks && callbacks.match_one) self.run_action(callbacks.match_one, [ data[0] ]);
          } else if (data.length > 1) {
            self.state = self.STATES.UNDEFINED;
            if (callbacks && callbacks.match_many) self.run_action(callbacks.match_many, [ data ]);
          } else {
            self.state = self.STATES.UNDEFINED;
            if (callbacks && callbacks.match_none) self.run_action(callbacks.match_none, [ self, self.$dummy.val() ]);
          }
          self.annotate_state();
        }
      });
    },
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
    handle_keydown: function(event) {
      var self = this;
      if (event.which == KEY.ENTER || event.which == KEY.TAB) {
        self.$dummy.autocomplete('close');

        // if string is empty assume they want to delete
        if (self.$dummy.val() === '') {
          self.set_item({});
          return true;
        } else if (self.state == self.STATES.PICKED) {
          if (self.o.action.commit_one) {
            self.run_action(self.o.action.commit_one);
          }
          return true;
        }
        if (event.which == KEY.TAB) {
          event.preventDefault();
          self.handle_changed_text();
        }
        if (event.which == KEY.ENTER) {
          event.preventDefault();
          self.handle_changed_text({
            match_none: self.o.action.commit_none,
            match_one:  self.o.action.commit_one,
            match_many: self.o.action.commit_many
          });
          return false;
        }
      } else if (event.which == KEY.DOWN && !self.autocomplete_open) {
        var old_options = self.$dummy.autocomplete('option');
        self.$dummy.autocomplete('option', 'minLength', 0);
        self.$dummy.autocomplete('search', self.$dummy.val());
        self.$dummy.autocomplete('option', 'minLength', old_options.minLength);
      } else if ((event.which != KEY.SHIFT) && (event.which != KEY.CTRL) && (event.which != KEY.ALT)) {
        self.state = self.STATES.UNDEFINED;
      }
    },
    open_dialog: function() {
      if (this.o.multiple) {
        this.o.multiple = this.multiple_default;
        this.dialog = new ns.PickerMultiPopup(this);
      } else {
        this.dialog = new ns.PickerPopup(this);
      }
    },
    close_dialog: function() {
      this.dialog.close_dialog();
      this.dialog = undefined;
    },
    init: function() {
      var self = this;
      this.$dummy.autocomplete({
        source: function(req, rsp) {
          $.ajax($.extend(self.o, {
            url:      'controller.pl?action=Part/ajax_autocomplete',
            dataType: "json",
            data:     self.ajax_data(req.term),
            success:  function (data){ rsp(data); }
          }));
        },
        select: function(event, ui) {
          self.set_item(ui.item);
          if (self.o.action.commit_one) {
            self.run_action(self.o.action.commit_one);
          }
        },
        search: function(event) {
          if ((event.which == KEY.SHIFT) || (event.which == KEY.CTRL) || (event.which == KEY.ALT))
            event.preventDefault();
        },
        open: function() {
          const $widget = self.$dummy.autocomplete('widget');
          const input_bound = self.$dummy[0].getBoundingClientRect();

          // safe inner viewport height without scrollbars
          const viewport_height = Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0);

          // logic:
          // if the widget was already open, keep position
          // if fits above but not below: render above
          // else: render below
          if (!self.autocomplete_open) {
            if (input_bound.top > $widget.height() && input_bound.bottom + $widget.height() > viewport_height) {
              $widget.position({ my: "left bottom", at: "left top", of: self.$dummy });
              self.menu_above = true;
            } else {
              $widget.position({ my: "left top", at: "left bottom", of: self.$dummy });
              self.menu_above = false;
            }
          } else {
            if (self.menu_above) {
              $widget.position({ my: "left bottom", at: "left top", of: self.$dummy });
            } else {
              $widget.position({ my: "left top", at: "left bottom", of: self.$dummy });
            }
          }

          self.autocomplete_open = true;
        },
        close: function() {
          self.autocomplete_open = false;
        }
      });
      this.$dummy.keydown(function(event){ self.handle_keydown(event); });
      this.$dummy.on('paste', function(){
        setTimeout(function() {
          self.handle_changed_text();
        }, 1);
      });
      this.$dummy.blur(function(){
        window.clearTimeout(self.timer);
        self.timer = window.setTimeout(function() { self.annotate_state(); }, 100);
      });

      var popup_button = $('<span>').addClass('ppp_popup_button');
      this.$dummy.after(popup_button);
      popup_button.click(function() { self.open_dialog(); });
    },
    run_action: function(code, args) {
      if (typeof code === 'function')
        code.apply(this, args);
      else
        kivi.run(code, args);
    },
    clear: function() {
      this.set_item({});
    }
  };
  ns.Picker.prototype.STATES = {
    PICKED:    ns.Picker.prototype.CLASSES.PICKED,
    UNDEFINED: ns.Picker.prototype.CLASSES.UNDEFINED
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
        }, self.pp.ajax_data(this.pp.$dummy.val())),
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
      $('#part_picker_filter').keypress(function(e) { self.result_timer(e); }).focus();
      $('#no_paginate').change(function() { self.update_results(); });
      this.update_results();
    },
    update_results: function() {
      var self = this;
      $.ajax({
        url: 'controller.pl?action=Part/part_picker_result',
        data: $.extend({
          no_paginate: $('#no_paginate').prop('checked') ? 1 : 0,
        }, self.pp.ajax_data(function(){
          var val = $('#part_picker_filter').val();
          return val === undefined ? '' : val;
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
            ean:  $(this).children('input.part_picker_ean').val(),
            unit: $(this).children('input.part_picker_unit').val(),
            partnumber:  $(this).children('input.part_picker_partnumber').val(),
            description: $(this).children('input.part_picker_description').val(),
          });
          self.close_dialog();
          self.pp.$dummy.focus();
          return true;
        });
      });
      $('#part_selection').keydown(function(e){
        if (e.which == KEY.ESCAPE) {
          self.close_dialog();
          self.pp.$dummy.focus();
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
        this.timer = window.setTimeout(function() { self.update_results(); }, 100);
      }
    },
    close_dialog: function() {
      $('#part_selection').dialog('close');
    }
  };

  ns.PickerMultiPopup = function(pp) {
    this.pp       = pp;
    this.callback = 'Part/add_multi_' + this.pp.o.part_type + '_items';
    this.open_dialog();
  };

  ns.PickerMultiPopup.prototype = {
    open_dialog: function() {
      var self = this;
      $('#row_table_id thead a img').remove();

      kivi.popup_dialog({
        url: 'controller.pl?action=Part/show_multi_items_dialog',
        data: $.extend({
          real_id: self.pp.real_id,
          show_pos_input: self.pp.o.multiple_pos_input,
        }, self.pp.ajax_data(this.pp.$dummy.val())),
        id: 'jq_multi_items_dialog',
        dialog: {
          title: kivi.t8('Add multiple items'),
          width:  800,
          height: 800
        },
        load: function() {
          self.init_search();
        }
      });
      return true;
    },
    init_search: function() {
      var self = this;
      $('#multi_items_filter_table input, #multi_items_filter_table select').keydown(function(event) {
        if(event.which == KEY.ENTER) {
          event.preventDefault();
          self.update_results();
          return false;
        }
      });

      $('#multi_items_filter_all_substr_multi_ilike').focus();
      $('#multi_items_filter_button').click(function(){ self.update_results(); });
      $('#multi_items_filter_reset').click(function(){ $("#multi_items_form").resetForm(); });
      $('#continue_button').click(function(){ self.add_multi_items(); });
    },
    update_results: function() {
      var self = this;
      var data = $('#multi_items_form').serializeArray();
      data.push({ name: 'type',  value: self.pp.type });
      data.push({ name: 'limit', value: self.pp.o.multiple_limit });
      var ppdata = self.pp.ajax_data(function(){
        var val = $('#multi_items_filter').val();
        return val === undefined ? '' : val;
      });
      $.each(Object.keys(ppdata), function() {data.push({ name: 'multi_items.' + this, value: ppdata[this]});});
      $.ajax({
        url: 'controller.pl?action=Part/multi_items_update_result',
        data: data,
        method: 'post',
        success: function(data){
          $('#multi_items_result').html(data);
          self.init_results();
          self.enable_continue();
        }
      });
    },
    set_qty_to_one: function(clicked) {
      if ($(clicked).val() === '') {
        $(clicked).val(kivi.format_amount(1.00, -2));
      }
      $(clicked).select();
    },
    init_results: function() {
      var self = this;
      $('#multi_items_all_qty').change(function(event){
        $('.multi_items_qty').val($(event.target).val());
      });
      $('.multi_items_qty').click(function(){ self.set_qty_to_one(this); });
    },
    result_timer: function() {
    },
    close_dialog: function() {
      $('#jq_multi_items_dialog').dialog('close');
    },
    disable_continue: function() {
      $('#multi_items_result input, #multi_items_position').off("keydown");
      $('#continue_button').prop('disabled', true);
    },
    enable_continue: function() {
      var self = this;
      $('#multi_items_result input, #multi_items_position').keydown(function(event) {
        if(event.keyCode == KEY.ENTER) {
          event.preventDefault();
          self.add_multi_items();
          return false;
        }
      });
      $('#continue_button').prop('disabled', false);
    },
    add_multi_items: function() {
      // rows at all
      var n_rows = $('.multi_items_qty').length;
      if ( n_rows === 0) { return; }

      // filled rows
      n_rows = $('.multi_items_qty').filter(function() {
        return $(this).val().length > 0;
      }).length;
      if (n_rows === 0) { return; }

      this.disable_continue();

      var data = $('#multi_items_form').serializeArray();
      this.pp.set_multi_items(data);
    }
  };

  ns.reinit_widgets = function() {
    kivi.run_once_for('input.part_autocomplete', 'part_picker', function(elt) {
      if (!$(elt).data('part_picker'))
        $(elt).data('part_picker', new kivi.Part.Picker($(elt)));
    });

    kivi.run_once_for('#customerprice_rows', 'customerprice_row_sort_renumber', function(elt) {
      $(elt).on('sortstop', kivi.Part.customerprice_renumber_positions);
    });

    kivi.run_once_for('#makemodel_rows', 'makemodel_row_sort_renumber', function(elt) {
      $(elt).on('sortstop', kivi.Part.makemodel_renumber_positions);
    });

    kivi.run_once_for('#businessmodel_rows', 'businessmodel_row_sort_renumber', function(elt) {
      $(elt).on('sortstop', kivi.Part.businessmodel_renumber_positions);
    });
  };

  ns.init = function() {
    ns.reinit_widgets();
  };

  ns.add_to_basket = function() {
    var data = $('#ic').serializeArray();
    data.push({ name: 'action', value: 'Part/add_to_basket' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  $(function(){
    $('#ic').on('focusout', '.reformat_number', function(event) {
      ns.reformat_number(event);
    });

    $('#part_warehouse_id').change(kivi.Part.reload_bin_selection);

    ns.init();
  });
});
