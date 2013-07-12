namespace('kivi', function(k){
  k.PartPicker = function($real, options) {
    // short circuit in case someone double inits us
    if ($real.data("part_picker"))
      return $real.data("part_picker");

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
    var open_dialog = function(){
      open_jqm_window({
        url: 'controller.pl?action=Part/part_picker_search',
        data: $.extend({
          real_id: real_id,
        }, ajax_data($dummy.val())),
        id: 'part_selection',
      });
      return true;
    };

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

    function close_popup() {
      $('#part_selection').jqmClose()
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
    $dummy.keypress(function(event){
      if (event.keyCode == 13 || event.keyCode == 9) { // enter or tab or tab
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
              if (event.keyCode == 13)
                $('#update_button').click();
            } else if (data.length > 1) {
             if (event.keyCode == 13)
                open_dialog();
              else
                make_defined_state();
            } else {
              if (event.keyCode == 9)
                make_defined_state();
            }
          }
        });
        if (event.keyCode == 13)
          return false;
      } else {
        state = STATES.UNDEFINED;
      }
    });

//    $dummy.blur(make_defined_state);  // blur triggers also on open_jqm_dialog

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
        $('#part_selection').keypress(function(e){
           if (e.keyCode == 27) { // escape
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
