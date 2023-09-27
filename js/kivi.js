namespace("kivi", function(ns) {
  "use strict";

  ns._locale = {};
  ns._date_format   = {
    sep: '.',
    y:   2,
    m:   1,
    d:   0
  };
  ns._time_format = {
    sep: ':',
    h: 0,
    m: 1,
  };
  ns._number_format = {
    decimalSep:  ',',
    thousandSep: '.'
  };

  ns.setup_formats = function(params) {
    var res = (params.dates || "").match(/^([ymd]+)([^a-z])([ymd]+)[^a-z]([ymd]+)$/);
    if (res) {
      ns._date_format                      = { sep: res[2] };
      ns._date_format[res[1].substr(0, 1)] = 0;
      ns._date_format[res[3].substr(0, 1)] = 1;
      ns._date_format[res[4].substr(0, 1)] = 2;
    }

    res = (params.times || "").match(/^([hm]+)([^a-z])([hm]+)$/);
    if (res) {
      ns._time_format                      = { sep: res[2] };
      ns._time_format[res[1].substr(0, 1)] = 0;
      ns._time_format[res[3].substr(0, 1)] = 1;
    }

    res = (params.numbers || "").match(/^\d*([^\d]?)\d+([^\d])\d+$/);
    if (res)
      ns._number_format = {
        decimalSep:  res[2],
        thousandSep: res[1]
      };
  };

  ns.parse_date = function(date) {
    if (date === undefined)
      return undefined;

    if (date === '')
      return null;

    if (date === '0' || date === '00')
      return new Date();

    var parts = date.replace(/\s+/g, "").split(ns._date_format.sep);
    var today = new Date();

    // without separator?
    // assume fixed pattern, and extract parts again
    if (parts.length == 1) {
      date  = parts[0];
      parts = date.match(/../g);
      if (date.length == 8) {
        parts[ns._date_format.y] += parts.splice(ns._date_format.y + 1, 1)
      }
      else
      if (date.length == 6 || date.length == 4) {
      }
      else
      if (date.length == 1 || date.length == 2) {
        parts = []
        parts[ ns._date_format.y ] = today.getFullYear();
        parts[ ns._date_format.m ] = today.getMonth() + 1;
        parts[ ns._date_format.d ] = date;
      }
      else {
        return undefined;
      }
    }

    if (parts.length == 3) {
      var year = +parts[ ns._date_format.y ] || 0 * 1 || (new Date()).getFullYear();
      if (year > 9999)
        return undefined;
      if (year < 100) {
        year += year > 70 ? 1900 : 2000;
      }
      date = new Date(
        year,
        (parts[ ns._date_format.m ] || (today.getMonth() + 1)) * 1 - 1, // Months are 0-based.
        (parts[ ns._date_format.d ] || today.getDate()) * 1
      );
    } else if (parts.length == 2) {
      date = new Date(
        (new Date()).getFullYear(),
        (parts[ (ns._date_format.m > ns._date_format.d) * 1 ] || (today.getMonth() + 1)) * 1 - 1, // Months are 0-based.
        (parts[ (ns._date_format.d > ns._date_format.m) * 1 ] || today.getDate()) * 1
      );
    } else
      return undefined;

    return isNaN(date.getTime()) ? undefined : date;
  };

  ns.format_date = function(date) {
    if (isNaN(date.getTime()))
      return undefined;

    var parts = [ "", "", "" ]
    parts[ ns._date_format.y ] = date.getFullYear();
    parts[ ns._date_format.m ] = (date.getMonth() <  9 ? "0" : "") + (date.getMonth() + 1); // Months are 0-based, but days are 1-based.
    parts[ ns._date_format.d ] = (date.getDate()  < 10 ? "0" : "") + date.getDate();
    return parts.join(ns._date_format.sep);
  };

  ns.parse_time = function(time) {
    var now = new Date();

    if (time === undefined)
      return undefined;

    if (time === '')
      return null;

    if (time === '0')
      return now;

    // special case 1: military time in fixed "hhmm" format
    if (time.length == 4) {
      var res = time.match(/(\d\d)(\d\d)/);
      if (res) {
        now.setHours(res[1], res[2]);
        return now;
      } else {
        return undefined;
      }
    }

    var parts = time.replace(/\s+/g, "").split(ns._time_format.sep);
    if (parts.length == 2) {
      for (var idx in parts) {
        if (Number.isNaN(Number.parseInt(parts[idx])))
          return undefined;
      }
      now.setHours(parts[ns._time_format.h], parts[ns._time_format.m]);
      return now;
    } else
      return undefined;
  }

  ns.format_time = function(date) {
    if (isNaN(date.getTime()))
      return undefined;

    var parts = [ "", "" ]
    parts[ ns._time_format.h ] = date.getHours().toString().padStart(2, '0');
    parts[ ns._time_format.m ] = date.getMinutes().toString().padStart(2, '0');
    return parts.join(ns._time_format.sep);
  };

  ns.parse_amount = function(amount) {
    if (amount === undefined)
      return undefined;

    if (amount === '')
      return null;

    if (ns._number_format.decimalSep == ',')
      amount = amount.replace(/\./g, "").replace(/,/g, ".");

    amount = amount.replace(/[\',]/g, "");

    // Make sure no code wich is not a math expression ends up in eval().
    if (!amount.match(/^[0-9 ()\-+*/.]*$/))
      return undefined;

    amount = amount.replace(/^0+(\d+)/, '$1');

    /* jshint -W061 */
    try {
      return eval(amount);
    } catch (err) {
      return undefined;
    }
  };

  ns.round_amount = function(amount, places) {
    var neg  = amount >= 0 ? 1 : -1;
    var mult = Math.pow(10, places + 1);
    var temp = Math.abs(amount) * mult;
    var diff = Math.abs(1 - temp + Math.floor(temp));
    temp     = Math.floor(temp) + (diff <= 0.00001 ? 1 : 0);
    var dec  = temp % 10;
    temp    += dec >= 5 ? 10 - dec: dec * -1;

    return neg * temp / mult;
  };

  ns.format_amount = function(amount, places) {
    amount = amount || 0;

    if ((places !== undefined) && (places >= 0))
      amount = ns.round_amount(amount, Math.abs(places));

    var parts = ("" + Math.abs(amount)).split(/\./);
    var intg  = parts[0];
    var dec   = parts.length > 1 ? parts[1] : "";
    var sign  = amount  < 0      ? "-"      : "";

    if (places !== undefined) {
      while (dec.length < Math.abs(places))
        dec += "0";

      if ((places > 0) && (dec.length > Math.abs(places)))
        dec = d.substr(0, places);
    }

    if ((ns._number_format.thousandSep !== "") && (intg.length > 3)) {
      var len   = ((intg.length + 2) % 3) + 1,
          start = len,
          res   = intg.substr(0, len);
      while (start < intg.length) {
        res   += ns._number_format.thousandSep + intg.substr(start, 3);
        start += 3;
      }

      intg = res;
    }

    var sep = (places !== 0) && (dec !== "") ? ns._number_format.decimalSep : "";

    return sign + intg + sep + dec;
  };

  ns.t8 = function(text, params) {
    text = ns._locale[text] || text;
    var key, value

    if( Object.prototype.toString.call( params ) === '[object Array]' ) {
      var len = params.length;

      for(var i=0; i<len; ++i) {
        key = i + 1;
        value = params[i];
        text = text.split("#"+ key).join(value);
      }
    }
    else if( typeof params == 'object' ) {
      for(key in params) {
        value = params[key];
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
    $(element).on('ckeditor-ready', () => ns.focus_ckeditor(element));
  };

  ns.focus_ckeditor = function(element) {
    const editor = $(element).data('ckeditorInstance');
    if (editor) {
      editor.editing.view.focus();
    } else {
      ns.focus_ckeditor_when_ready(element);
    }
  };

  ns.init_tabwidget = function(element) {
    var $element   = $(element);
    var tabsParams = {};
    var elementId  = $element.attr('id');

    if (elementId) {
      var cookieName      = 'jquery_ui_tab_'+ elementId;
      if (!window.location.hash) {
        // only activate if there's no hash to overwrite it
        tabsParams.active   = $.cookie(cookieName);
      }
      tabsParams.activate = function(event, ui) {
        var i = ui.newTab.parent().children().index(ui.newTab);
        $.cookie(cookieName, i);
      };
    }

    $element.tabs(tabsParams);
  };

  ns.init_text_editor5 = function($element) {
    ClassicEditor
    .create($element.get(0), {
      toolbar: [
        'bold', 'italic', 'underline', 'strikethrough',
        '|',
        'subscript', 'superscript',
        '|',
        'bulletedList', 'numberedList', 'horizontalLine',
        '|',
        'undo', 'redo', 'removeFormat',
        '|',
        'sourceEditing'
      ],
      language: {
        ui: kivi.myconfig.countrycode,
        content: kivi.myconfig.countrycode
      }
    })
    .then(editor => {
      // save instance in data
      $element.data('ckeditorInstance', editor);

      // handle auto focus
      if ($element.hasClass('texteditor-autofocus'))
        ns.focus_ckeditor($element);

      // trigger delayed hooks on the editor
      $element.trigger('ckeditor-ready');

      // make sure blur events copy back to the textarea
      // this catches most of the non-submit ways that ckeditor doesn't handle
      // on its own. if you have any bugs, make sure to call updateSourceElement
      // directly before serializing the form
      editor.ui.focusTracker.on( 'change:isFocused', (evt, name, is_focused) => {
        if (!is_focused) {
          editor.updateSourceElement();
        }
      });

      // handle inital disabled
      if ($element.attr('disabled'))
        editor.enableReadOnlyMode('disabled')

      // handle initial height
      const element = $element.get(0);
      if (element.style.height)
        editor.editing.view.change((writer) => {
          writer.setStyle(
            "min-height",
            element.style.height,
            editor.editing.view.document.getRoot()
          );
        });
    })
    .catch(err => {
      console.error(err);
    });
  };

  ns.filter_select = function() {
    var $input  = $(this);
    var $select = $('#' + $input.data('select-id'));
    var filter  = $input.val().toLocaleLowerCase();

    $select.find('option').each(function() {
      if ($(this).text().toLocaleLowerCase().indexOf(filter) != -1)
        $(this).show();
      else
        $(this).hide();
    });
  };

  ns.reinit_widgets = function() {
    ns.run_once_for('.datepicker', 'datepicker', function(elt) {
      $(elt).datepicker();
    });

    if (ns.Part) ns.Part.reinit_widgets();
    if (ns.CustomerVendor) ns.CustomerVendor.reinit_widgets();
    if (ns.Validator) ns.Validator.reinit_widgets();
    if (ns.Materialize) ns.Materialize.reinit_widgets();

    if (ns.ProjectPicker)
      ns.run_once_for('input.project_autocomplete', 'project_picker', function(elt) {
        kivi.ProjectPicker($(elt));
      });

    if (ns.ChartPicker)
      ns.run_once_for('input.chart_autocomplete', 'chart_picker', function(elt) {
        kivi.ChartPicker($(elt));
      });

    ns.run_once_for('div.filtered_select input', 'filtered_select', function(elt) {
      $(elt).bind('change keyup', ns.filter_select);
    });

    var func = kivi.get_function_by_name('local_reinit_widgets');
    if (func)
      func();

    ns.run_once_for('.tooltipster', 'tooltipster', function(elt) {
      $(elt).tooltipster({
        contentAsHTML: false,
        theme: 'tooltipster-light'
      })
    });

    ns.run_once_for('.tooltipster-html', 'tooltipster-html', function(elt) {
      $(elt).tooltipster({
        contentAsHTML: true,
        theme: 'tooltipster-light'
      })
    });

    ns.run_once_for('.tabwidget', 'tabwidget', kivi.init_tabwidget);
    ns.run_once_for('.texteditor', 'texteditor', kivi.init_text_editor5);
  };

  ns.submit_ajax_form = function(url, form_selector, additional_data) {
    $(form_selector).ajaxSubmit({
      url:     url,
      data:    additional_data,
      success: ns.eval_json_result
    });

    return true;
  };

  // This function submits an existing form given by "form_selector"
  // and sets the "action" input to "action_to_call" before submitting
  // it. Any existing input named "action" will be removed prior to
  // submitting.
  ns.submit_form_with_action = function(form_selector, action_to_call) {
    $('[name=action]').remove();

    var $form   = $(form_selector);
    var $hidden = $('<input type=hidden>');

    $hidden.attr('name',  'action');
    $hidden.attr('value', action_to_call);
    $form.append($hidden);

    $form.submit();
  };

  // This function exists solely so that it can be found with
  // kivi.get_functions_by_name() and called later on. Using something
  // like "var func = history["back"]" works, but calling it later
  // with "func.apply()" doesn't.
  ns.history_back = function() {
    history.back();
  };

  // Return a function object by its name (a string). Works both with
  // global functions (e.g. "focus_by_name") and those in namespaces (e.g.
  // "kivi.t8").
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
  // 'id') or given via param.html. If an existing DOM div should be used then
  // the element won't be removed upon closing the dialog which allows
  // re-opening it later on.
  //
  // Parameters:
  // - id: dialog DIV ID (optional; defaults to 'jqueryui_popup_dialog')
  // - url, data, type: passed as the first three arguments to the $.ajax() call if an AJAX call is made, otherwise ignored.
  // - dialog: an optional object of options passed to the $.dialog() call
  // - load: an optional function that is called after the content has been loaded successfully (only if an AJAX call is made)
  ns.popup_dialog = function(params) {
    if (kivi.Materialize)
      return kivi.Materialize.popup_dialog(params);

    var dialog;

    params            = params        || { };
    var id            = params.id     || 'jqueryui_popup_dialog';
    var custom_close  = params.dialog ? params.dialog.close : undefined;
    var dialog_params = $.extend(
      { // kivitendo default parameters:
          width:  800
        , height: 500
        , modal:  true
      },
        // User supplied options:
      params.dialog || { },
      { // Options that must not be changed:
        close: function(event, ui) {
          dialog.dialog('close');

          if (custom_close)
            custom_close();

          if (params.url || params.html)
            dialog.remove();
        }
      });

    if (!params.url && !params.html) {
      // Use existing DOM element and show it. No AJAX call.
      dialog =
        $('#' + id)
        .bind('dialogopen', function() {
          ns.run_once_for('.texteditor-in-dialog,.texteditor-dialog', 'texteditor', kivi.init_text_editor5);
        })
        .dialog(dialog_params);
      return true;
    }

    $('#' + id).remove();

    dialog = $('<div style="display:none" class="loading" id="' + id + '"></div>').appendTo('body');
    dialog.dialog(dialog_params);

    if (params.html) {
      dialog.html(params.html);
    } else {
      // no html? get it via ajax
      $.ajax({
        url:     params.url,
        data:    params.data,
        type:    params.type,
        success: function(new_html) {
          dialog.html(new_html);
          dialog.removeClass('loading');
          if (params.load)
            params.load();
        }
      });
    }

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

    $(selector).filter(function() { return $(this).data(attr_name) !== true; }).each(function(idx, elt) {
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
      return fn.apply({}, args || []);

    console.error('kivi.run("' + function_name + '"): No function by that name found');
    return undefined;
  };

  ns.save_file = function(base64_data, content_type, size, attachment_name) {
    // atob returns a unicode string with one codepoint per octet. revert this
    const b64toBlob = (b64Data, contentType='', sliceSize=512) => {
      const byteCharacters = atob(b64Data);
      const byteArrays = [];

      for (let offset = 0; offset < byteCharacters.length; offset += sliceSize) {
        const slice = byteCharacters.slice(offset, offset + sliceSize);

        const byteNumbers = new Array(slice.length);
        for (let i = 0; i < slice.length; i++) {
          byteNumbers[i] = slice.charCodeAt(i);
        }

        const byteArray = new Uint8Array(byteNumbers);
        byteArrays.push(byteArray);
      }

      const blob = new Blob(byteArrays, {type: contentType});
      return blob;
    }

    var blob = b64toBlob(base64_data, content_type);
    var a = $("<a style='display: none;'/>");
    var url = window.URL.createObjectURL(blob);
    a.attr("href", url);
    a.attr("download", attachment_name);
    $("body").append(a);
    a[0].click();
    window.URL.revokeObjectURL(url);
    a.remove();
  }

  ns.detect_duplicate_ids_in_dom = function() {
    var ids   = {},
        found = false;

    $('[id]').each(function() {
      if (this.id && ids[this.id]) {
        found = true;
        console.warn('Duplicate ID #' + this.id);
      }
      ids[this.id] = 1;
    });

    if (!found)
      console.log('No duplicate IDs found :)');
  };

  ns.validate_form = function(selector) {
    if (!kivi.Validator) {
      console.log('kivi.Validator is not loaded');
    } else {
      return kivi.Validator.validate_all(selector);
    }
  };

  // Verifies that at least one checkbox matching the
  // "checkbox_selector" is actually checked. If not, an error message
  // is shown, and false is returned. Otherwise (at least one of them
  // is checked) nothing is shown and true returned.
  //
  // Can be used in checks when clicking buttons.
  ns.check_if_entries_selected = function(checkbox_selector) {
    if ($(checkbox_selector + ':checked').length > 0)
      return true;

    alert(kivi.t8('No entries have been selected.'));

    return false;
  };

  ns.switch_areainput_to_textarea = function(id) {
    var $input = $('#' + id);
    if (!$input.length)
      return;

    var $area = $('<textarea></textarea>');

    $area.prop('rows', 3);
    $area.prop('cols', $input.prop('size') || 40);
    $area.prop('name', $input.prop('name'));
    $area.prop('id',   $input.prop('id'));
    $area.val($input.val());

    $input.parent().replaceWith($area);
    $area.focus();
  };

  ns.set_cursor_position = function(selector, position) {
    var $input = $(selector);
    if (position === 'end')
      position = $input.val().length;

    $input.prop('selectionStart', position);
    $input.prop('selectionEnd',   position);
  };

  ns._shell_escape = function(str) {
    if (str.match(/^[a-zA-Z0-9.,_=+/-]+$/))
      return str;

    return "'" + str.replace(/'/, "'\\''") + "'";
  };

  ns.call_as_curl = function(params) {
    params      = params || {};
    var uri     = document.documentURI.replace(/\?.*/, '');
    var command = ['curl', '--user', kivi.myconfig.login + ':SECRET', '--request', params.method || 'POST']

    $(params.data || []).each(function(idx, elt) {
      command = command.concat([ '--form-string', elt.name + '=' + (elt.value || '') ]);
    });

    command.push(uri);

    return $.map(command, function(elt, idx) {
      return kivi._shell_escape(elt);
    }).join(' ');
  };

  ns.serialize = function(source, target = [], prefix, in_array = false) {
    let arr_prefix = first => in_array ? (first ? "[+]" : "[]") : "";

    if (Array.isArray(source) ) {
      source.forEach(( val, i ) => {
        ns.serialize(val, target, prefix + arr_prefix(i == 0), true);
      });
    } else if (typeof source === "object") {
      let first = true;
      for (let key in source) {
        ns.serialize(source[key], target, (prefix !== undefined ? prefix + arr_prefix(first) + "." : "") + key);
        first = false;
      }
    } else {
      target.push({ name: prefix + arr_prefix(false), value: source });
    }

    return target;
  };
});

kivi = namespace('kivi');
