[%- USE T8 %]
$(function() {
[% IF datefmt %]
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

function fokus() {
[%- IF focus -%]
  $('[% focus %]').focus();
[%- END -%]
}
