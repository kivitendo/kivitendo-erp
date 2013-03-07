[%- USE T8 %]
$(function() {
[% IF datefmt %]
  namespace("kivi").initLocale("[% MYCONFIG.countrycode | html %]");
  setupPoints('[% MYCONFIG.numberformat %]', '[% 'wrongformat' | $T8 %]');
  setupDateFormat('[% MYCONFIG.dateformat %]', '[% 'Falsches Datumsformat!' | $T8 %]');

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

  $('.datepicker').each(function() {
    $(this).datepicker();
  });
[% END %]

[% IF ajax_spinner %]
  $(document).ajaxSend(function() {
    $('#ajax-spinner').show();
  }).ajaxStop(function() {
    $('#ajax-spinner').hide();
  });
[% END %]
});

function fokus() {
[%- IF focus -%]
  $('[% focus %]').focus();
[%- END -%]
}
