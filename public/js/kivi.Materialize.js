namespace("kivi.Materialize", function(ns) {
  "use strict";

  ns.init = function() {
    ns.reinit_widgets();
  };

  ns.build_i18n = function() {
    return {
      months: [
        kivi.t8('January'),
        kivi.t8('February'),
        kivi.t8('March'),
        kivi.t8('April'),
        kivi.t8('May'),
        kivi.t8('June'),
        kivi.t8('July'),
        kivi.t8('August'),
        kivi.t8('September'),
        kivi.t8('October'),
        kivi.t8('November'),
        kivi.t8('December')
      ],
      monthsShort: [
        kivi.t8('Jan'),
        kivi.t8('Feb'),
        kivi.t8('Mar'),
        kivi.t8('Apr'),
        kivi.t8('May'),
        kivi.t8('Jun'),
        kivi.t8('Jul'),
        kivi.t8('Aug'),
        kivi.t8('Sep'),
        kivi.t8('Oct'),
        kivi.t8('Nov'),
        kivi.t8('Dec')
      ],
      weekdays: [
        kivi.t8('Sunday'),
        kivi.t8('Monday'),
        kivi.t8('Tuesday'),
        kivi.t8('Wednesday'),
        kivi.t8('Thursday'),
        kivi.t8('Friday'),
        kivi.t8('Saturday')
      ],
      weekdaysShort: [
        kivi.t8('Sun'),
        kivi.t8('Mon'),
        kivi.t8('Tue'),
        kivi.t8('Wed'),
        kivi.t8('Thu'),
        kivi.t8('Fri'),
        kivi.t8('Sat')
      ],

      // Buttons
      today: kivi.t8('Today'),
      done: kivi.t8('Ok'),
      clear: kivi.t8('Clear'),
      cancel: kivi.t8('Cancel'),

      // Accessibility labels
      labelMonthNext: kivi.t8('Next month'),
      labelMonthPrev: kivi.t8('Previous month')
    };
  };

  ns.flash = function(text) {
    M.toast({html: text});
  };

  ns.reinit_widgets = function() {
    $('.sidenav').sidenav();
    $('select').formSelect();
    $('.datepicker').datepicker({
      firstDay: 1,
      format: kivi.myconfig.dateformat,
      showClearBtn: true,
      i18n: ns.build_i18n()
    });
    $('.modal').modal();
    $('.materialboxed').materialbox();
    M.updateTextFields();
  };

  // alternative for kivi.popup_dialog.
  // opens materialize modal instead.
  //
  // differences: M.modal can not load external content, so it needs to be fetched manually and inserted into the DOM.
  ns.popup_dialog = function(params) {
    params            = params        || { };
    let id            = params.id     || 'jqueryui_popup_dialog';
    let $div;
    let custom_close  = params.dialog ? params.dialog.close : undefined;
    let dialog_params = $.extend(
      { // kivitendo default parameters.
        // unlike classic layout, there is not fixed size, and M.modal is always... modal
        onCloseStart: custom_close
      },
      // User supplied options:
      params.dialog || { },
      { // Options that must not be changed:
        // close options already work
      });

    if (params.url) {
      $.ajax({
        url: params.url,
        data: params.data,
        success: function(data) {
          params.html = data;
          params.url = undefined;
          params.data = undefined;
          ns.popup_dialog(params);
        },
        error: function(x, status, error) { console.error(error); },
        dataType: 'text',
      });
      return 1;
    }

    if (params.html) {
      $div = $('<div>');
      $div.attr('id', id);
      $div.addClass("modal");
      let $modal_content = $('<div>');
      $modal_content.addClass('modal-content');
      $modal_content.html(params.html);
      $div.append($modal_content);
      $('body').append($div);
      kivi.reinit_widgets();
      dialog_params.onCloseEnd = function() { $div.remove(); };

      $div.modal(dialog_params);
    } else if(params.id) {
      $div = $('#' + params.id);
    } else {
      console.error("insufficient parameters to open dialog");
      return 0;
    }

    $div.modal('open');

    return true;
  };

  ns.flash_type_to_color_class = {
    error:   "red",
    warning: "orange",
    info:    "blue",
    ok:      "green"
  };


  /**
   * Flash interface. Materialize has toasts that do the same things
   * so simply redirect the Flash interface into toasts
   */
  ns.display_flash = function(type, message, details, timestamp) {
    // to save screenspace, don't include the timestamp or the translated type
    let $content = $('<div>');

    if (message !== undefined && message !== null) {
      let $message = $('<p>');
      $message.html(message);
      $content.append($message);
    }

    if (details !== undefined && details !== null) {
      let $details =  $('<p>');
      $details.html(details);
      $content.append($details);
    }

    M.toast({
      html:          $content,
      displayLength: 60 * 1000,
      classes:       ns.flash_type_to_color_class[type]
    });
  }
  ns.clear_flash = function(category, timeout) {
    M.Toast.dismissAll()
  }


  /**
   * upload file to local storage for later sync
   *
   * should be used with P.M.file_upload(..., local=>1)
   */
  ns.LocalFileUpload = function(options) {
    this.storage_token = options.storage_token; // used in localstorage to retrieve the file
    this.dom_selector  = options.dom_selector;  // file inputs to listen on

    this.init();
  };

  ns.LocalFileUpload.prototype = {
    init: function() {
      $(this.dom_selector).change(this.handle_file_upload);
    },
    handle_file_upload: function() {

    },
    load_files: function() {
      return JSON.parse(localStorage.getImte(this.storage_token));
    },
    save_files: function() {
      return JSON.parse(localStorage.getImte(this.storage_token));
    },

  };

});
