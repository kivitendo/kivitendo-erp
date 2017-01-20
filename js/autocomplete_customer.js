namespace('kivi', function(k){
  "use strict";

  k.CustomerVendorPicker = function($real, options) {
    // short circuit in case someone double inits us
    if ($real.data("customer_vendor_picker"))
      return $real.data("customer_vendor_picker");

    var KEY = {
      ESCAPE: 27,
      ENTER:  13,
      TAB:    9,
      LEFT:   37,
      RIGHT:  39,
      PAGE_UP: 33,
      PAGE_DOWN: 34,
    };
    var CLASSES = {
      PICKED:       'customer-vendor-picker-picked',
      UNDEFINED:    'customer-vendor-picker-undefined',
      FAT_SET_ITEM: 'customer-vendor-picker-fat-set-item',
    }
    var o = $.extend({
      limit: 20,
      delay: 50,
      fat_set_item: $real.hasClass(CLASSES.FAT_SET_ITEM),
    }, options);
    var STATES = {
      PICKED:    CLASSES.PICKED,
      UNDEFINED: CLASSES.UNDEFINED
    }
    var real_id = $real.attr('id');
    var $dummy  = $('#' + real_id + '_name');
    var $type   = $('#' + real_id + '_type');
    var $unit   = $('#' + real_id + '_unit');
    var state   = STATES.PICKED;
    var last_real = $real.val();
    var last_dummy = $dummy.val();
    var timer;

    function ajax_data(term) {
      var data = {
        'filter.all:substr:multi::ilike': term,
        'filter.obsolete': 0,
        current:  $real.val(),
        type:     $type.val(),
      };

      return data;
    }

    function set_item (item) {
      if (item.id) {
        $real.val(item.id);
        // autocomplete ui has name, ajax items have description
        $dummy.val(item.name ? item.name : item.description);
      } else {
        $real.val('');
        $dummy.val('');
      }
      state = STATES.PICKED;
      last_real = $real.val();
      last_dummy = $dummy.val();
      last_unverified_dummy = $dummy.val();
      $real.trigger('change');

      if (o.fat_set_item && item.id) {
        $.ajax({
          url: 'controller.pl?action=CustomerVendor/show.json',
          data: { id: item.id, db: item.type },
          success: function(rsp) {
            $real.trigger('set_item:CustomerVendorPicker', rsp);
          },
        });
      } else {
        $real.trigger('set_item:CustomerVendorPicker', item);
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
        last_unverified_dummy = $dummy.val();
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
        last_unverified_dummy = $dummy.val();
        $dummy.addClass(STATES.UNDEFINED).removeClass(STATES.PICKED);
      }
    }

    function handle_changed_text(callbacks) {
      $.ajax({
        url: 'controller.pl?action=CustomerVendor/ajaj_autocomplete',
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
          url:      'controller.pl?action=CustomerVendor/ajaj_autocomplete',
          dataType: "json",
          data:     ajax_data(req.term),
          success:  function (data){ rsp(data) }
        }));
      },
      select: function(event, ui) {
        set_item(ui.item);
      },
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
      } else {
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
    var pp = {
      real:           function() { return $real },
      dummy:          function() { return $dummy },
      type:           function() { return $type },
      set_item:       set_item,
      reset:          make_defined_state,
      is_defined_state: function() { return state == STATES.PICKED },
    }
    $real.data('customer_vendor_picker', pp);
    return pp;
  }
});

$(function(){
  $('input.customer_vendor_autocomplete').each(function(i,real){
    kivi.CustomerVendorPicker($(real));
  })
});
