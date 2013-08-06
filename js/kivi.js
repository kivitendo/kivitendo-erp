namespace("kivi", function(ns) {
  ns._locale = {};

  ns.t8 = function(text, params) {
    var text = ns._locale[text] || text;

    if( Object.prototype.toString.call( params ) === '[object Array]' ) {
      var len = params.length;

      for(var i=0; i<len; ++i) {
        var key = i + 1;
        var value = params[i];
        text = text.split("#"+ key).join(value);
      }
    }
    else if( typeof params == 'object' ) {
      for(var key in params) {
        var value = params[key];
        text = text.split("#{"+ key +"}").join(value);
      }
    }

    return text;
  };

  ns.setupLocale = function(locale) {
    ns._locale = locale;
  };

  ns.reinit_widgets = function() {
    $('.datepicker').each(function() {
      $(this).datepicker();
    });

    if (ns.PartPicker)
      $('input.part_autocomplete').each(function(idx, elt){
        kivi.PartPicker($(elt));
      });
  };

  ns.submit_ajax_form = function(url, form_selector, additional_data) {
    $(form_selector).ajaxSubmit({
      url:     url,
      data:    additional_data,
      success: ns.eval_json_result
    });

    return true;
  };

  // Return a function object by its name (a string). Works both with
  // global functions (e.g. "check_right_date_format") and those in
  // namespaces (e.g. "kivi.t8").
  // Returns null if the object is not found.
  ns.get_function_by_name = function(name) {
    var parts = name.match("(.+)\\.([^\\.]+)$");
    if (!parts)
      return window[name];
    return namespace(parts[1])[ parts[2] ];
  };

  // Open a modal jQuery UI popup dialog. The content is loaded via AJAX.
  //
  // Parameters:
  // - id: dialog DIV ID (optional; defaults to 'jqueryui_popup_dialog')
  // - url, data, type: passed as the first three arguments to the $.ajax() call
  // - dialog: an optional object of options passed to the $.dialog() call
  ns.popup_dialog = function(params) {
    var dialog;

    params            = params        || { };
    var id            = params.id     || 'jqueryui_popup_dialog';
    var dialog_params = $.extend(
      { // kivitendo default parameters:
          width:  800
        , height: 500
        , modal:  true
      },
        // User supplied options:
      params.dialog || { },
      { // Options that must not be changed:
        close: function(event, ui) { dialog.remove(); }
      });

    $('#' + id).remove();

    dialog = $('<div style="display:none" class="loading" id="' + id + '"></div>').appendTo('body');
    dialog.dialog(dialog_params);

    $.ajax({
      url:     params.url,
      data:    params.data,
      type:    params.type,
      success: function(new_html) {
        dialog.html(new_html);
        dialog.removeClass('loading');
      }
    });

    return true;
  };
});

kivi = namespace('kivi');
