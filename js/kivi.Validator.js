namespace("kivi.Validator", function(ns) {
  "use strict";

  // Performs various validation steps on the descendants of
  // 'selector'. Elements that should be validated must have an
  // attribute named "data-validate" which is set to a space-separated
  // list of tests to perform. Additionally, the attribute
  // "data-title" can be set to a human-readable name of the field
  // that can be shown in front of an error message.
  //
  // Supported validation tests are:
  // - "required": the field must be set (its .val() must not be empty)
  // - "number": the field must be in number format (its .val() must in the right format)
  // - "date": the field must be in date format (its .val() must in the right format)
  // - "time": the field must be in time format (its .val() must in the right format)
  //
  // The validation will abort and return "false" as soon as
  // validation routine fails.
  //
  // The function returns "true" if all validations succeed for all
  // elements.
  ns.validate_all = function(selector) {
    selector = selector || '#form';
    var to_check = $(selector + ' [data-validate]').toArray();

    for (var to_check_idx in to_check)
      if (!ns.validate($(to_check[to_check_idx]))) {
        $(to_check[to_check_idx]).focus();
        return false;
      }

    return true;
  };

  ns.validate = function($e) {
    /*
    var $e_annotate;
    if ($e.data('ckeditorInstance')) {
      $e_annotate = $($e.data('ckeditorInstance').editable().$);
      if ($e.data('title'))
        $e_annotate.data('title', $e.data('title'));
    }*/
    var tests = $e.data('validate').split(/ +/);

    for (var test_idx in tests) {
      var test = tests[test_idx];
      if (!ns.checks[test])
        continue;

      if (ns.checks[test]) {
        if (!ns.checks[test]($e))
          return false;
      } else {
        var error = "kivi.validate_form: unknown test '" + test + "' for element ID '" + $e.prop('id') + "'";
        console.error(error);
        alert(error);
        return false;
      }
    }

    return true;
  }

  ns.val = function($e, data) {
    if ($e.data('ckeditorInstance')) {
      if (data === undefined)
        return $e.data('ckeditorInstance').getData()
      else
        $e.data('ckeditorInstance').setData(data)
    } else {
      if (data === undefined)
        return $e.val();
      else
        $e.val(data);
    }
  }

  ns.checks = {
    required: function($e, $e_annotate) {
      $e_annotate = $e_annotate || $e;

      if (ns.val($e) === '') {
        ns.annotate($e_annotate, kivi.t8("This field must not be empty."));
        return false;
      } else {
        ns.annotate($e_annotate);
        return true;
      }
    },
    number: function($e, $e_annotate) {
      $e_annotate = $e_annotate || $e;

      var number_string = ns.val($e);

      var parsed_number = kivi.parse_amount(number_string);

      if (parsed_number === null) {
        ns.val($e, '');
        ns.annotate($e_annotate);
        return true;
      } else
      if (parsed_number === undefined) {
        ns.annotate($e_annotate, kivi.t8('Wrong number format (#1)', [ kivi.myconfig.numberformat ]));
        return false;
      } else
      {
        let input_decimal_places = parsed_number.toString().split('.')[1];
        let count_input_decimal_places = 0;
        if(input_decimal_places){
          count_input_decimal_places = input_decimal_places.length;
        }
        var formatted_number = kivi.format_amount(parsed_number);
        if (formatted_number != number_string) {
          ns.val($e, formatted_number);
          if(count_input_decimal_places > decimal_places) {
            kivi.display_flash('warning',kivi.t8('Input was rounded'));
          }
        }
        ns.annotate($e_annotate);
        return true;
      }
    },
    date: function($e, $e_annotate) {
      $e_annotate = $e_annotate || $e;

      var date_string = ns.val($e);

      var parsed_date = kivi.parse_date(date_string);

      if (parsed_date === null) {
        ns.val($e, '');
        ns.annotate($e_annotate);
        return true;
      } else
      if (parsed_date === undefined) {
        ns.annotate($e_annotate, kivi.t8('Wrong date format (#1)', [ kivi.myconfig.dateformat ]));
        return false;
      } else
      {
        var formatted_date = kivi.format_date(parsed_date);
        if (formatted_date != date_string)
          ns.val($e, formatted_date);
        ns.annotate($e_annotate);
        return true;
      }
    },
    time: function($e, $e_annotate) {
      $e_annotate = $e_annotate || $e;

      var time_string = ns.val($e);

      var parsed_time = kivi.parse_time(time_string);
      if (parsed_time === null) {
        ns.val($e, '');
        ns.annotate($e_annotate);
        return true;
      } else
      if (parsed_time === undefined) {
        ns.annotate($e_annotate, kivi.t8('Wrong time format (#1)', [ kivi.myconfig.timeformat ]));
        return false;
      } else
      {
        var formatted_time = kivi.format_time(parsed_time);
        if (formatted_time != time_string)
          ns.val($e, formatted_time);
        ns.annotate($e_annotate);
        return true;
      }
    },
    trimmed_whitespaces: function($e, $e_annotate) {
      $e_annotate = $e_annotate || $e;

      var string = ns.val($e);

      if ($e.hasClass('tooltipstered'))
        $e.tooltipster('destroy');

      if (string.match(/^\s|\s$/)) {
        ns.val($e, string.trim());

        $e.tooltipster({
          content: kivi.t8("Leading and trailing whitespaces have been removed."),
          contentAsHTML: true,
          theme: 'tooltipster-light',
        });
        $e.tooltipster('show');
      }
      return true;
    }
  };

  ns.annotate = function($e, error) {
      // if element is ckeditor:
    if ($e.data('ckeditorInstance')) {
      const $orig_e = $e;
      $e = $($orig_e.data('ckeditorInstance').ui.view.editable._editableElement);
      if ($orig_e.data('title'))
        $e.data('title', $orig_e.data('title'));
    }

    if (error) {
      $e.addClass('kivi-validator-invalid');
      if ($e.hasClass('tooltipstered'))
        $e.tooltipster('destroy');

      if ($e.data('title'))
        error = $e.data('title') + ': ' + error;

      $e.tooltipster({
        content: error,
        theme: 'tooltipster-light',
      });
      $e.tooltipster('show');
    } else {
      $e.removeClass('kivi-validator-invalid');
      if ($e.hasClass('tooltipstered'))
        $e.tooltipster('destroy');
    }
  };

  ns.reinit_widgets = function() {
    kivi.run_once_for('[data-validate]', 'data-validate', function(elt) {
      $(elt).change(function(event){ ns.validate($(elt), event) });
    });
  }

  ns.init = ns.reinit_widgets;

  $(ns.init);
});
