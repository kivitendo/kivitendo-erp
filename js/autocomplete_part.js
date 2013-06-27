namespace('kivi', function(k){
  k.part_picker = function($real, options) {
    o = $.extend({
      limit: 20,
      delay: 50,
    }, options);

    var real_id = $real.attr('id');
    var $dummy  = $('#' + real_id + '_name');
    var $type   = $('#' + real_id + '_type');
    var $column = $('#' + real_id + '_column');
    var open_dialog = function(){
      open_jqm_window({
        url: 'controller.pl',
        data: {
          action: 'Part/part_picker_search',
          real_id: real_id,
          'filter.all:substr::ilike': function(){ return $dummy.val() },
          'filter.type':              function(){ return $type.val() },
          'column':                   function(){ return $column.val() },
        },
        id: 'part_selection',
      });
      return true;
    };

    var ajax_data = function(term) {
      return {
        term:     term,
        type:     function() { return $type.val() },
        column:   function() { return $column.val()===undefined ? '' : $column.val() },
        current:  function() { return $real.val() },
        obsolete: 0,
      }
    }

    var set_item = function (item) {
      if (item.id) {
        $real.val(item.id);
        // autocomplete ui has name, ajax items have description
        $dummy.val(item.name ? item.name : item.description);
      } else {
        $real.val('');
        $dummy.val('');
      }
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
        }
        $.ajax({
          url: 'controller.pl?action=Part/ajax_autocomplete',
          dataType: "json",
          data: ajax_data($dummy.val()),
          success: function (data){
            if (data.length == 1) {
              set_item(data[0]);
              if (event.keyCode == 13)
                $('#update_button').click();
            } else {
              if (event.keyCode == 13)
                open_dialog();
              else
                set_item({});
            }
          }
        });
        if (event.keyCode == 13)
          return false;
      };
    });

    $dummy.blur(function(){
      if ($dummy.val() == '')
        $real.val('');
    });

    // now add a picker div after the original input
    var pcont  = $('<span>').addClass('position-absolute');
    var picker = $('<div>');
    $dummy.after(pcont);
    pcont.append(picker);
    picker.addClass('icon16 CRM--Schnellsuche').click(open_dialog);
  }
});

$(function(){
  $('input.part_autocomplete').each(function(i,real){
    kivi.part_picker($(real));
  })
});
