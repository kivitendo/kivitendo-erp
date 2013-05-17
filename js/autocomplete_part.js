$(function(){
  $('input.part_autocomplete').each(function(i,real){
    var $dummy  = $('#' + real.id + '_name');
    var $type   = $('#' + real.id + '_type');
    var $column = $('#' + real.id + '_column');
    $dummy.autocomplete({
      source: function(req, rsp) {
        $.ajax({
          url: 'controller.pl?action=Part/ajax_autocomplete',
          dataType: "json",
          data: {
            term: req.term,
            type: function() { return $type.val() },
            column: function() { return $column.val()===undefined ? '' : $column.val() },
            current: function() { return real.value },
            obsolete: 0,
          },
          success: function (data){ rsp(data) }
        });
      },
      limit: 20,
      delay: 50,
      select: function(event, ui) {
        $(real).val(ui.item.id);
        $dummy.val(ui.item.name);
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
        // if string is empty asume they want to delete
        if ($dummy.val() == '') {
          $(real).val('');
          return true;
        }
        $.ajax({
          url: 'controller.pl?action=Part/ajax_autocomplete',
          dataType: "json",
          data: {
            term: $dummy.val(),
            type: function() { return $type.val() },
            column: function() { return $column.val()===undefined ? '' : $column.val() },
            current: function() { return real.value },
            obsolete: 0,
          },
          success: function (data){
            // only one
            if (data.length == 1) {
              $(real).val(data[0].id);
              $dummy.val(data[0].description);
              if (event.keyCode == 13)
                $('#update_button').click();
            }
          }
        });
        if (event.keyCode == 13)
          return false;
      };
    });

    $dummy.blur(function(){
      if ($dummy.val() == '')
        $(real).val('');
    })

    // now add a picker div after the original input
    var pcont  = $('<span>').addClass('position-absolute');
    var picker = $('<div>');
    $dummy.after(pcont);
    pcont.append(picker);
    picker.addClass('icon16 CRM--Schnellsuche').click(function(){
      open_jqm_window({
        url: 'controller.pl',
        data: {
          action: 'Part/part_picker_search',
          real_id: function() { return $(real).attr('id') },
          'filter.all:substr::ilike': function(){ return $dummy.val() },
          'filter.type': function(){ return $type.val() },
          'column': function(){ return $column.val() },
          'real_id': function() { return real.id },
        },
        id: 'part_selection',
      });
      return true;
    });
  });
})
