namespace('kivi', function(k){
  "use strict";

  k.ProjectPicker = function($real, options) {
    // short circuit in case someone double inits us
    if ($real.data("project_picker"))
      return $real.data("project_picker");

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
      PICKED:       'projectpicker-picked',
      UNDEFINED:    'projectpicker-undefined',
    }
    var o = $.extend({
      limit: 20,
      delay: 50,
    }, $real.data('project-picker-data'), options);
    var STATES = {
      PICKED:    CLASSES.PICKED,
      UNDEFINED: CLASSES.UNDEFINED
    }
    var real_id      = $real.attr('id');
    var $dummy       = $('#' + real_id + '_name');
    var $customer_id = $('#' + real_id + '_customer_id');
    var state        = STATES.PICKED;
    var last_real    = $real.val();
    var last_dummy   = $dummy.val();
    var timer;

    function open_dialog () {
      k.popup_dialog({
        url: 'controller.pl?action=Project/project_picker_search',
        // data that can be accessed in template project_picker_search via FORM.boss
        data: $.extend({  // add id of part to the rest of the data in ajax_data, e.g. no_paginate, booked, ...
          real_id: real_id,
          select: 1,
        }, ajax_data($dummy.val())),
        id: 'project_selection',
        dialog: {
          title: k.t8('Project picker'),
          width: 800,
          height: 800,
        },
        load: function() { init_search(); }
      });
      window.clearTimeout(timer);
      return true;
    }

    function init_search() {
      $('#project_picker_filter').keypress(function(e) { result_timer(e) }).focus();
      $('#no_paginate').change(function() { update_results() });
      $('#project_picker_clear_filter').click(function() {
        $('#project_picker_filter').val('').focus();
        update_results();
      });
    }

    function ajax_data(term) {
      var data = {
        'filter.all:substr:multi::ilike': term,
        no_paginate:  $('#no_paginate').prop('checked') ? 1 : 0,
        current:  $real.val(),
      };

      if (o.customer_id)
        data['filter.customer_id'] = o.customer_id.split(',');

      if (o.active) {
        if (o.active === 'active')   data['filter.active'] = 'active';
        if (o.active === 'inactive') data['filter.active'] = 'inactive';
        // both => no filter
      } else {
        data['filter.active'] = 'active'; // default
      }

      if (o.valid) {
        if (o.valid === 'valid')   data['filter.valid'] = 'valid';
        if (o.valid === 'invalid') data['filter.valid'] = 'invalid';
        // both => no filter
      } else {
        data['filter.valid'] = 'valid'; // default
      }

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
      $real.trigger('set_item:ProjectPicker', item);

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
        url: 'controller.pl?action=Project/project_picker_result',
        data: $.extend({
            'real_id': $real.val(),
        }, ajax_data(function(){ var val = $('#project_picker_filter').val(); return val === undefined ? '' : val })),
        success: function(data){
          $('#project_picker_result').html(data);
        }
      });
    }

    function result_timer (event) {
      if (!$('no_paginate').prop('checked')) {
        if (event.keyCode == KEY.PAGE_UP) {
          $('#project_picker_result a.paginate-prev').click();
          return;
        }
        if (event.keyCode == KEY.PAGE_DOWN) {
          $('#project_picker_result a.paginate-next').click();
          return;
        }
      }
      window.clearTimeout(timer);
      timer = window.setTimeout(update_results, 100);
    }

    function close_popup() {
      $('#project_selection').dialog('close');
    }

    function handle_changed_text(callbacks) {
      $.ajax({
        url: 'controller.pl?action=Project/ajax_autocomplete',
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
          url:      'controller.pl?action=Project/ajax_autocomplete',
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
    var popup_button = $('<span>').addClass('ppp_popup_button');
    $dummy.after(popup_button);
    popup_button.click(open_dialog);
    var pp = {
      real:           function() { return $real },
      dummy:          function() { return $dummy },
      update_results: update_results,
      result_timer:   result_timer,
      set_item:       set_item,
      reset:          make_defined_state,
      is_defined_state: function() { return state == STATES.PICKED },
      init_results: function() {
        $('div.project_picker_project').each(function(){
          $(this).click(function(){
            set_item({
              id:   $(this).children('input.project_picker_id').val(),
              name: $(this).children('input.project_picker_description').val(),
            });
            close_popup();
            $dummy.focus();
            return true;
          });  });
        $('#project_selection').keydown(function(e){
          if (e.which == KEY.ESCAPE) {
            close_popup();
            $dummy.focus();
          }
        });
      }
    }
    $real.data('project_picker', pp);
    return pp;
  }
});

$(function(){
  $('input.project_autocomplete').each(function(i,real){
    kivi.ProjectPicker($(real));
  })
});
