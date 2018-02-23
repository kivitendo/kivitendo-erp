namespace("kivi.Validator", function(ns) {
  "use strict";

  // Performs various validation steps on the descendants of
  // 'selector'. Elements that should be validated must have an
  // attribute named "data-validate" which is set to a space-separated
  // list of tests to perform. Additionally, the attribute
  // "data-title" must be set to a human-readable name of the field
  // that can be shown as part of an error message.
  //
  // Supported validation tests are:
  // - "required": the field must be set (its .val() must not be empty)
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

  ns.checks = {
    required: function($e) {
      if ($e.val() === '') {
        ns.annotate($e, kivi.t8("This field must not be empty."));
        return false;
      } else {
        ns.annotate($e);
        return true;
      }
    },
    number: function($e) {
      var number_string = $e.val();

      var parsed_number = kivi.parse_amount(number_string);

      if (parsed_number === null) {
        $e.val('');
        ns.annotate($e);
        return true;
      } else
      if (parsed_number === undefined) {
        ns.annotate($e, kivi.t8('Wrong number format (#1)', [ kivi.myconfig.numberformat ]));
        return false;
      } else
      {
        var formatted_number = kivi.format_amount(parsed_number);
        if (formatted_number != number_string)
          $e.val(formatted_number);
        ns.annotate($e);
        return true;
      }
    },
    date: function($e) {
      var date_string = $e.val();

      var parsed_date = kivi.parse_date(date_string);

      if (parsed_date === null) {
        $e.val('');
        ns.annotate($e);
        return true;
      } else
      if (parsed_date === undefined) {
        ns.annotate($e, kivi.t8('Wrong date format (#1)', [ kivi.myconfig.dateformat ]));
        return false;
      } else
      {
        var formatted_date = kivi.format_date(parsed_date);
        if (formatted_date != date_string)
          $e.val(formatted_date);
        ns.annotate($e);
        return true;
      }
    },
    time: function($e) {
      var time_string = $e.val();

      var parsed_time = kivi.parse_time(time_string);
      if (parsed_time === null) {
        $e.val('');
        ns.annotate($e);
        return true;
      } else
      if (parsed_time === undefined) {
        ns.annotate($e, kivi.t8('Wrong time format (#1)', [ kivi.myconfig.timeformat ]));
        return false;
      } else
      {
        var formatted_time = kivi.format_time(parsed_time);
        if (formatted_time != time_string)
          $e.val(formatted_time);
        ns.annotate($e);
        return true;
      }
    }
  };

  ns.annotate = function($e, error) {
    if (error) {
      $e.addClass('kivi-validator-invalid');
      if ($e.hasClass('tooltipstered'))
        $e.tooltipster('destroy');

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
