[%- USE T8 %]
[%- USE JavaScript %]
$(function() {
[% IF datefmt %]
  setupPoints('[% JavaScript.escape(MYCONFIG.numberformat) %]', '[% 'wrongformat' | $T8 %]');
  setupDateFormat('[% JavaScript.escape(MYCONFIG.dateformat) %]', '[% 'Falsches Datumsformat!' | $T8 %]');

  $.datepicker.setDefaults(
    $.extend({}, $.datepicker.regional["[% MYCONFIG.countrycode %]"], {
      dateFormat: "[% datefmt %]",
      showOn: "button",
      showButtonPanel: true,
      changeMonth: true,
      changeYear: true,
      buttonImage: "image/calendar.png",
      buttonImageOnly: true
  }));

  kivi.setup_formats({
    numbers: '[% JavaScript.escape(MYCONFIG.numberformat) %]',
    dates:   '[% JavaScript.escape(MYCONFIG.dateformat) %]'
  });

  kivi.reinit_widgets();
[% END %]

[% IF ajax_spinner %]
  $(document).ajaxSend(function() {
    $('#ajax-spinner').show();
  }).ajaxStop(function() {
    $('#ajax-spinner').hide();
  });
[% END %]
});

[%- IF focus -%]
function fokus() {
  $('[% focus %]').focus();
}
[%- END -%]
