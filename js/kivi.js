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

  ns.set_focus = function(element) {
    var $e = $(element).eq(0);
    if ($e.data('ckeditorInstance'))
      ns.focus_ckeditor_when_ready($e);
    else
      $e.focus();
  };

  ns.focus_ckeditor_when_ready = function(element) {
    $(element).ckeditor(function() { ns.focus_ckeditor(element); });
  };

  ns.focus_ckeditor = function(element) {
    var editor   = $(element).ckeditorGet();
		var editable = editor.editable();

		if (editable.is('textarea')) {
			var textarea = editable.$;

			if (CKEDITOR.env.ie)
				textarea.createTextRange().execCommand('SelectAll');
			else {
				textarea.selectionStart = 0;
				textarea.selectionEnd   = textarea.value.length;
			}

			textarea.focus();

		} else {
			if (editable.is('body'))
				editor.document.$.execCommand('SelectAll', false, null);

			else {
				var range = editor.createRange();
				range.selectNodeContents(editable);
				range.select();
			}

			editor.forceNextSelectionCheck();
			editor.selectionChange();

      editor.focus();
		}
  };

  ns.init_tabwidget = function(element) {
    var $element   = $(element);
    var tabsParams = {};
    var elementId  = $element.attr('id');

    if (elementId) {
      var cookieName      = 'jquery_ui_tab_'+ elementId;
      tabsParams.active   = $.cookie(cookieName);
      tabsParams.activate = function(event, ui) {
        var i = ui.newTab.parent().children().index(ui.newTab);
        $.cookie(cookieName, i);
      };
    }

    $element.tabs(tabsParams);
  };

  ns.init_text_editor = function(element) {
    var layouts = {
      all:     [ [ 'Bold', 'Italic', 'Underline', 'Strike', '-', 'Subscript', 'Superscript' ], [ 'BulletedList', 'NumberedList' ], [ 'RemoveFormat' ] ],
      default: [ [ 'Bold', 'Italic', 'Underline', 'Strike', '-', 'Subscript', 'Superscript' ], [ 'BulletedList', 'NumberedList' ], [ 'RemoveFormat' ] ]
    };

    var $e      = $(element);
    var buttons = layouts[ $e.data('texteditor-layout') || 'default' ] || layouts['default'];
    var config  = {
      entities:      false,
      language:      'de',
      removePlugins: 'resize',
      toolbar:       buttons
    }

    var style = $e.prop('style');
    $(['width', 'height']).each(function(idx, prop) {
      var matches = (style[prop] || '').match(/(\d+)px/);
      if (matches && (matches.length > 1))
        config[prop] = matches[1];
    });

    $e.ckeditor(config);

    if ($e.hasClass('texteditor-autofocus'))
      $e.ckeditor(function() { ns.focus_ckeditor($e); });
  };

  ns.reinit_widgets = function() {
    ns.run_once_for('.datepicker', 'datepicker', function(elt) {
      $(elt).datepicker();
    });

    if (ns.PartPicker)
      ns.run_once_for('input.part_autocomplete', 'part_picker', function(elt) {
        kivi.PartPicker($(elt));
      });

    var func = kivi.get_function_by_name('local_reinit_widgets');
    if (func)
      func();

    ns.run_once_for('.tooltip', 'tooltip', function(elt) {
      $(elt).tooltip();
    });

    ns.run_once_for('.tabwidget', 'tabwidget', kivi.init_tabwidget);
    ns.run_once_for('.texteditor', 'texteditor', kivi.init_text_editor);
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

  // Open a modal jQuery UI popup dialog. The content can be either
  // loaded via AJAX (if the parameter 'url' is given) or simply
  // displayed if it exists in the DOM already (referenced via
  // 'id'). If an existing DOM div should be used then the element
  // won't be removed upon closing the dialog which allows re-opening
  // it later on.
  //
  // Parameters:
  // - id: dialog DIV ID (optional; defaults to 'jqueryui_popup_dialog')
  // - url, data, type: passed as the first three arguments to the $.ajax() call if an AJAX call is made, otherwise ignored.
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
        close: function(event, ui) { if (params.url) dialog.remove(); else dialog.dialog('close'); }
      });

    if (!params.url) {
      // Use existing DOM element and show it. No AJAX call.
      dialog =
        $('#' + id)
        .bind('dialogopen', function() {
          ns.run_once_for('.texteditor-in-dialog,.texteditor-dialog', 'texteditor', kivi.init_text_editor);
        })
        .dialog(dialog_params);
      return true;
    }

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

  // Run code only once for each matched element
  //
  // This allows running the function 'code' exactly once for each
  // element that matches 'selector'. This is achieved by storing the
  // state with jQuery's 'data' function. The 'identification' is
  // required for differentiating unambiguously so that different code
  // functions can still be run on the same elements.
  //
  // 'code' can be either a function or the name of one. It must
  // resolve to a function that receives the jQueryfied element as its
  // sole argument.
  //
  // Returns nothing.
  ns.run_once_for = function(selector, identification, code) {
    var attr_name = 'data-run-once-for-' + identification.toLowerCase().replace(/[^a-z]+/g, '-');
    var fn        = typeof code === 'function' ? code : ns.get_function_by_name(code);
    if (!fn) {
      console.error('kivi.run_once_for(..., "' + code + '"): No function by that name found');
      return;
    }

    $(selector).filter(function() { return $(this).data(attr_name) != true; }).each(function(idx, elt) {
      var $elt = $(elt);
      $elt.data(attr_name, true);
      fn($elt);
    });
  };

  // Run a function by its name passing it some arguments
  //
  // This is a function useful mainly for the ClientJS functionality.
  // It finds a function by its name and then executes it on an empty
  // object passing the elements in 'args' (an array) as the function
  // parameters retuning its result.
  //
  // Logs an error to the console and returns 'undefined' if the
  // function cannot be found.
  ns.run = function(function_name, args) {
    var fn = ns.get_function_by_name(function_name);
    if (fn)
      return fn.apply({}, args);

    console.error('kivi.run("' + function_name + '"): No function by that name found');
    return undefined;
  };
});

kivi = namespace('kivi');
