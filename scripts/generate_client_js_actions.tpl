// NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE:

// This file is generated automatically by the script
// "scripts/generate_client_js_actions.pl". See the documentation for
// SL/ClientJS.pm for instructions.

namespace("kivi", function(ns) {

ns.eval_json_result = function(data) {
  if (!data)
    return;

  if (data.error)
    return ns.Flash.display_flash('error', data.error);

  if ((data.js || '') !== '')
    // jshint -W061
    eval(data.js);
    // jshint +W061

  if (data.eval_actions)
    $(data.eval_actions).each(function(idx, action) {
      // console.log("ACTION " + action[0] + " ON " + action[1]);

[% actions %]
    });

  // console.log("current_content_type " + $('#current_content_type').val() + ' ID ' + $('#current_content_id').val());
};

});

// Local Variables:
// mode: js
// End:
