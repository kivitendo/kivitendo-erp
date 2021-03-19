namespace("kivi.Materialize", function(ns) {
  "use strict";

  ns.init = function() {
    ns.reinit_widgets();
  }

  ns.build_i18n = function(locale) {
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
    }
  }

  ns.reinit_widgets = function() {
    $('.sidenav').sidenav();
    $('select').formSelect();
    $('.datepicker').datepicker({
      firstDay: 1,
      format: kivi.myconfig.dateformat,
      showClearBtn: true,
      i18n: ns.build_i18n()
    });
    M.updateTextFields();
  }

});
