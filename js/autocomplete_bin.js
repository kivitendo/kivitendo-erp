namespace('kivi', function(k){
  "use strict";

  k.BinPicker = function($real, options) {
    // short circuit in case someone double inits us
    if ($real.data("bin_picker"))
      return $real.data("bin_picker");

    var KEY = {
      ESCAPE: 27,
      ENTER:  13,
      TAB:    9,
      LEFT:   37,
      RIGHT:  39,
      PAGE_UP: 33,
      PAGE_DOWN: 34,
      SHIFT:     16,
      CTRL:      17,
      ALT:       18,
    };
    var CLASSES = {
      PICKED:       'binpicker-picked',
      UNDEFINED:    'binpicker-undefined',
    }
    var o = $.extend({
      limit: 20,
      delay: 50,
    }, options);
    var STATES = {
      PICKED:    CLASSES.PICKED,
      UNDEFINED: CLASSES.UNDEFINED
    }
    var real_id      = $real.attr('id');
    var $dummy       = $('#' + real_id + '_name');
    var $warehouse_field = $('#' + real_id + '_warehouse_field');
    var $warehouse_id = $('#' + $warehouse_field.val());
    var state        = STATES.PICKED;
    var last_real    = $real.val();
    var last_dummy   = $dummy.val();
    var timer;

    function ajax_data(term) {
      var data = {
        'filter.all:substr:multi::ilike': term,
        no_paginate:  $('#no_paginate').prop('checked') ? 1 : 0,
        current:  $real.val(),
      };

      if ($warehouse_id && $warehouse_id.val())
        data['filter.warehouse_id'] = $warehouse_id.val().split(',');

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
      $real.trigger('set_item:BinPicker', item);

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

    function update_results () {
      $.ajax({
        url: 'controller.pl?action=Bin/bin_picker_result',
        data: $.extend({
            'real_id': $real.val(),
        }, ajax_data(function(){ var val = $('#bin_picker_filter').val(); return val === undefined ? '' : val })),
        success: function(data){ $('#bin_picker_result').html(data) }
      });
    }

    function result_timer (event) {
      if (!$('no_paginate').prop('checked')) {
        if (event.keyCode == KEY.PAGE_UP) {
          $('#bin_picker_result a.paginate-prev').click();
          return;
        }
        if (event.keyCode == KEY.PAGE_DOWN) {
          $('#bin_picker_result a.paginate-next').click();
          return;
        }
      }
      window.clearTimeout(timer);
      timer = window.setTimeout(update_results, 100);
    }

    function handle_changed_text(callbacks) {
      $.ajax({
        url: 'controller.pl?action=Bin/ajax_autocomplete',
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
            if (callbacks &&callbacks.match_none) callbacks.match_none();
          }
          annotate_state();
        }
      });
    }

    $dummy.autocomplete({
      source: function(req, rsp) {
        $.ajax($.extend(o, {
          url:      'controller.pl?action=Bin/ajax_autocomplete',
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
            match_one:  function(){$('#update_button').click();},
          });
          return false;
        }
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
    var pcont  = $('<span>').addClass('position-absolute');
    var picker = $('<div>');
    $dummy.after(pcont);
    pcont.append(picker);

    var pp = {
      real:           function() { return $real },
      dummy:          function() { return $dummy },
      type:           function() { return $type },
      customer_id:    function() { return $customer_id },
      update_results: update_results,
      result_timer:   result_timer,
      set_item:       set_item,
      reset:          make_defined_state,
      is_defined_state: function() { return state == STATES.PICKED },
      init_results:    function () {
        $('div.bin_picker_bin').each(function(){
          $(this).click(function(){
            set_item({
              id:   $(this).children('input.bin_picker_id').val(),
              name: $(this).children('input.bin_picker_description').val(),
            });
            $dummy.focus();
            return true;
          });
        });
        $('#bin_selection').keydown(function(e){
           if (e.which == KEY.ESCAPE) {
             $dummy.focus();
           }
        });
      }
    }
    $real.data('bin_picker', pp);
    return pp;
  }
});

$(function(){
  $('input.bin_autocomplete').each(function(i,real){
    kivi.BinPicker($(real));
  })
});
