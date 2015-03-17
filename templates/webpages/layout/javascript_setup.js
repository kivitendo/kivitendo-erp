[%- USE T8 %]
[%- USE JSON %]
$(function() {
[% IF datefmt %]
  setupPoints([% JSON.json(MYCONFIG.numberformat) %], '[% 'wrongformat' | $T8 %]');
  setupDateFormat([% JSON.json(MYCONFIG.dateformat) %], '[% 'Falsches Datumsformat!' | $T8 %]');

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

[%- IF focus -%]
function fokus() {
  $('[% focus %]').focus();
}
[%- END -%]
