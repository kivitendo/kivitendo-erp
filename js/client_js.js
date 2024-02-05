// NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE:

// This file is generated automatically by the script
// "scripts/generate_client_js_actions.pl". See the documentation for
// SL/ClientJS.pm for instructions.

namespace("kivi", function(ns) {

ns.eval_json_result = function(data) {
  if (!data)
    return;

  if (data.error && ns.Flash)
    return ns.Flash.display_flash('error', data.error);

  if ((data.js || '') !== '')
    // jshint -W061
    eval(data.js);
    // jshint +W061

  if (data.eval_actions)
    $(data.eval_actions).each(function(idx, action) {
      // console.log("ACTION " + action[0] + " ON " + action[1]);

      // ## jQuery basics ##
      // Basic effects
           if (action[0] == 'hide')                 $(action[1]).hide();
      else if (action[0] == 'show')                 $(action[1]).show();
      else if (action[0] == 'toggle')               $(action[1]).toggle();

      // DOM insertion, around
      else if (action[0] == 'unwrap')               $(action[1]).unwrap();
      else if (action[0] == 'wrap')                 $(action[1]).wrap(action[2]);
      else if (action[0] == 'wrapAll')              $(action[1]).wrapAll(action[2]);
      else if (action[0] == 'wrapInner')            $(action[1]).wrapInner(action[2]);

      // DOM insertion, inside
      else if (action[0] == 'append')               $(action[1]).append(action[2]);
      else if (action[0] == 'appendTo')             $(action[1]).appendTo(action[2]);
      else if (action[0] == 'html')                 $(action[1]).html(action[2]);
      else if (action[0] == 'prepend')              $(action[1]).prepend(action[2]);
      else if (action[0] == 'prependTo')            $(action[1]).prependTo(action[2]);
      else if (action[0] == 'text')                 $(action[1]).text(action[2]);

      // DOM insertion, outside
      else if (action[0] == 'after')                $(action[1]).after(action[2]);
      else if (action[0] == 'before')               $(action[1]).before(action[2]);
      else if (action[0] == 'insertAfter')          $(action[1]).insertAfter(action[2]);
      else if (action[0] == 'insertBefore')         $(action[1]).insertBefore(action[2]);

      // DOM removal
      else if (action[0] == 'empty')                $(action[1]).empty();
      else if (action[0] == 'remove')               $(action[1]).remove();

      // DOM replacement
      else if (action[0] == 'replaceAll')           $(action[1]).replaceAll(action[2]);
      else if (action[0] == 'replaceWith')          $(action[1]).replaceWith(action[2]);

      // General attributes
      else if (action[0] == 'attr')                 $(action[1]).attr(action[2], action[3]);
      else if (action[0] == 'prop')                 $(action[1]).prop(action[2], action[3]);
      else if (action[0] == 'removeAttr')           $(action[1]).removeAttr(action[2]);
      else if (action[0] == 'removeProp')           $(action[1]).removeProp(action[2]);
      else if (action[0] == 'val')                  $(action[1]).val(action[2]);

      // Class attribute
      else if (action[0] == 'addClass')             $(action[1]).addClass(action[2]);
      else if (action[0] == 'removeClass')          $(action[1]).removeClass(action[2]);
      else if (action[0] == 'toggleClass')          $(action[1]).toggleClass(action[2]);

      // Data storage
      else if (action[0] == 'data')                 $(action[1]).data(action[2], action[3]);
      else if (action[0] == 'removeData')           $(action[1]).removeData(action[2]);

      // Form Events
      else if (action[0] == 'focus')                kivi.set_focus(action[1]);

      // Generic Event Handling ##
      else if (action[0] == 'on')                   $(action[1]).on(action[2], kivi.get_function_by_name(action[3]));
      else if (action[0] == 'off')                  $(action[1]).off(action[2], kivi.get_function_by_name(action[3]));
      else if (action[0] == 'one')                  $(action[1]).one(action[2], kivi.get_function_by_name(action[3]));

      // ## jQuery UI dialog plugin ##

      // Opening and closing a popup
      else if (action[0] == 'dialog:open')          kivi.popup_dialog(action[1]);
      else if (action[0] == 'dialog:close')         $(action[1]).dialog('close');

      // ## jQuery Form plugin ##
      else if (action[0] == 'ajaxForm')             $(action[1]).ajaxForm({ success: eval_json_result });

      // ## jstree plugin ##

      // Operations on the whole tree
      else if (action[0] == 'jstree:lock')          $.jstree._reference($(action[1])).lock();
      else if (action[0] == 'jstree:unlock')        $.jstree._reference($(action[1])).unlock();

      // Opening and closing nodes
      else if (action[0] == 'jstree:open_node')     $.jstree._reference($(action[1])).open_node(action[2]);
      else if (action[0] == 'jstree:open_all')      $.jstree._reference($(action[1])).open_all(action[2]);
      else if (action[0] == 'jstree:close_node')    $.jstree._reference($(action[1])).close_node(action[2]);
      else if (action[0] == 'jstree:close_all')     $.jstree._reference($(action[1])).close_all(action[2]);
      else if (action[0] == 'jstree:toggle_node')   $.jstree._reference($(action[1])).toggle_node(action[2]);
      else if (action[0] == 'jstree:save_opened')   $.jstree._reference($(action[1])).save_opened();
      else if (action[0] == 'jstree:reopen')        $.jstree._reference($(action[1])).reopen();

      // Modifying nodes
      else if (action[0] == 'jstree:create_node')   $.jstree._reference($(action[1])).create_node(action[2], action[3], action[4]);
      else if (action[0] == 'jstree:rename_node')   $.jstree._reference($(action[1])).rename_node(action[2], action[3]);
      else if (action[0] == 'jstree:delete_node')   $.jstree._reference($(action[1])).delete_node(action[2]);
      else if (action[0] == 'jstree:move_node')     $.jstree._reference($(action[1])).move_node(action[2], action[3], action[4], action[5]);

      // Selecting nodes (from the 'ui' plugin to jstree)
      else if (action[0] == 'jstree:select_node')   $.jstree._reference($(action[1])).select_node(action[2], true);
      else if (action[0] == 'jstree:deselect_node') $.jstree._reference($(action[1])).deselect_node(action[2]);
      else if (action[0] == 'jstree:deselect_all')  $.jstree._reference($(action[1])).deselect_all();

      // ## ckeditor stuff ##
      else if (action[0] == 'focus_ckeditor')       kivi.focus_ckeditor_when_ready(action[1]);

      // ## other stuff ##
      else if (action[0] == 'redirect_to')          window.location.href = action[1];
      else if (action[0] == 'save_file')            kivi.save_file(action[1], action[2], action[3], action[4]);

      // flash
      else if (action[0] == 'flash')                kivi.Flash.display_flash.apply({}, action.slice(1, action.length));
      else if (action[0] == 'clear_flash')          kivi.Flash.clear_flash();
      else if (action[0] == 'show_flash')           kivi.Flash.show();
      else if (action[0] == 'hide_flash')           kivi.Flash.hide();
      else if (action[0] == 'reinit_widgets')       kivi.reinit_widgets();
      else if (action[0] == 'run')                  kivi.run(action[1], action.slice(2, action.length));
      else if (action[0] == 'run_once_for')         kivi.run_once_for(action[1], action[2], action[3]);
      else if (action[0] == 'scroll_into_view')     $(action[1])[0].scrollIntoView();
      else if (action[0] == 'set_cursor_position')  kivi.set_cursor_position(action[1], action[2]);

      else                                          console.log('Unknown action: ' + action[0]);

    });

  // console.log("current_content_type " + $('#current_content_type').val() + ' ID ' + $('#current_content_id').val());
};

});

// Local Variables:
// mode: js
// End:
