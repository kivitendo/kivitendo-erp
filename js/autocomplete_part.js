namespace('kivi', function(k){
  k.PartPicker = function($real, options) {
    // short circuit in case someone double inits us
    if ($real.data("part_picker"))
      return $real.data("part_picker");

    var KEY = {
      ESCAPE: 27,
      ENTER:  13,
      TAB:    9,
    };
    var o = $.extend({
      limit: 20,
      delay: 50,
    }, options);
    var STATES = {
      UNIQUE: 1,
      UNDEFINED: 0,
    }
    var real_id = $real.attr('id');
    var $dummy  = $('#' + real_id + '_name');
    var $type   = $('#' + real_id + '_type');
    var $unit   = $('#' + real_id + '_unit');
    var $convertible_unit = $('#' + real_id + '_convertible_unit');
    var $column = $('#' + real_id + '_column');
    var state   = STATES.PICKED;
    var last_real = $real.val();
    var last_dummy = $dummy.val();
    var timer;

    function open_dialog () {
      k.popup_dialog({
        url: 'controller.pl?action=Part/part_picker_search',
        data: $.extend({
          real_id: real_id,
        }, ajax_data($dummy.val())),
        id: 'part_selection',
        dialog: { title: k.t8('Part picker') }
      });
      window.clearTimeout(timer);
      return true;
    }

    function ajax_data(term) {
      var data = {
        'filter.all:substr::ilike': term,
        'filter.obsolete': 0,
        'filter.unit_obj.convertible_to': $convertible_unit && $convertible_unit.val() ? $convertible_unit.val() : '',
        column:   $column && $column.val() ? $column.val() : '',
        current:  $real.val(),
      };

      if ($type && $type.val())
        data['filter.type'] = $type.val().split(',');

      if ($unit && $unit.val())
        data['filter.unit'] = $unit.val().split(',');

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
      $real.trigger('change');
    }

    function make_defined_state () {
      if (state == STATES.PICKED)
        return true
      else if (state == STATES.UNDEFINED && $dummy.val() == '')
        set_item({})
      else
        set_item({ id: last_real, name: last_dummy })
    }

    function update_results () {
      $.ajax({
        url: 'controller.pl?action=Part/part_picker_result',
        data: $.extend({
            'real_id': $real.val(),
        }, ajax_data(function(){ var val = $('#part_picker_filter').val(); return val === undefined ? '' : val })),
        success: function(data){ $('#part_picker_result').html(data) }
      });
    };

    function result_timer (event) {
      window.clearTimeout(timer);
      timer = window.setTimeout(update_results, 100);
    }

    function close_popup() {
      $('#part_selection').dialog('close');
    };

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
     *  TODO: users expect tab to work on keydown but enter to trigger on keyup,
     *        should be handled seperately
     */
    $dummy.keydown(function(event){
      if (event.which == KEY.ENTER || event.which == KEY.TAB) { // enter or tab or tab
        // if string is empty assume they want to delete
        if ($dummy.val() == '') {
          set_item({});
          return true;
        } else if (state == STATES.PICKED) {
          return true;
        }
        $.ajax({
          url: 'controller.pl?action=Part/ajax_autocomplete',
          dataType: "json",
          data: $.extend( ajax_data($dummy.val()), { prefer_exact: 1 } ),
          success: function (data){
            if (data.length == 1) {
              set_item(data[0]);
              if (event.which == KEY.ENTER)
                $('#update_button').click();
            } else if (data.length > 1) {
             if (event.which == KEY.ENTER)
                open_dialog();
              else
                make_defined_state();
            } else {
              if (event.which == KEY.TAB)
                make_defined_state();
            }
          }
        });
        if (event.which == KEY.ENTER)
          return false;
      } else {
        state = STATES.UNDEFINED;
      }
    });

    $dummy.blur(function(){
      window.clearTimeout(timer);
      timer = window.setTimeout(make_defined_state, 100);
    });

    // now add a picker div after the original input
    var pcont  = $('<span>').addClass('position-absolute');
    var picker = $('<div>');
    $dummy.after(pcont);
    pcont.append(picker);
    picker.addClass('icon16 CRM--Schnellsuche').click(open_dialog);

    var pp = {
      real:           function() { return $real },
      dummy:          function() { return $dummy },
      type:           function() { return $type },
      unit:           function() { return $unit },
      convertible_unit: function() { return $convertible_unit },
      column:         function() { return $column },
      update_results: update_results,
      result_timer:   result_timer,
      set_item:       set_item,
      reset:          make_defined_state,
      init_results:    function () {
        $('div.part_picker_part').each(function(){
          $(this).click(function(){
            set_item({
              name: $(this).children('input.part_picker_description').val(),
              id:   $(this).children('input.part_picker_id').val(),
            });
            close_popup();
            return true;
          });
        });
        $('#part_selection').keydown(function(e){
           if (e.which == KEY.ESCAPE) {
             close_popup();
             $dummy.focus();
           }
        });
      }
    }
    $real.data('part_picker', pp);
    return pp;
  }
});

$(function(){
  $('input.part_autocomplete').each(function(i,real){
    kivi.PartPicker($(real));
  })
});
