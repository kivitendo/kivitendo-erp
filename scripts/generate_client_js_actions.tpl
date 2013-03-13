// NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE:

// This file is generated automatically by the script
// "scripts/generate_client_js_actions.pl". See the documentation for
// SL/ClientJS.pm for instructions.

function display_flash(type, message) {
  $('#flash_' + type + '_content').text(message);
  $('#flash_' + type).show();
}

function eval_json_result(data) {
  if (!data)
    return;

  if (data.error)
    return display_flash('error', data.error);

  $('#flash_error').hide();
  $('#flash_error_content').empty();

  if ((data.js || '') != '')
    eval(data.js);

  if (data.eval_actions)
    $(data.eval_actions).each(function(idx, action) {
      // console.log("ACTION " + action[0] + " ON " + action[1]);

[% actions %]
    });

  // console.log("current_content_type " + $('#current_content_type').val() + ' ID ' + $('#current_content_id').val());
}

function submit_ajax_form(url, form_selector, additional_data) {
  var separator = /\?/.test(url) ? '&' : '?';
  $.post(url + separator + $(form_selector).serialize(), additional_data, eval_json_result);
  return true;
}

// Local Variables:
// mode: js
// End:
