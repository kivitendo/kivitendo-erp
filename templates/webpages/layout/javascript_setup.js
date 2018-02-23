[%- USE LxERP %]
[%- USE JavaScript %]
[%- USE JSON %]
kivi.myconfig = [% JSON.json(MYCONFIG) %];
$(function() {
  $.datepicker.setDefaults(
    $.extend({}, $.datepicker.regional[kivi.myconfig.countrycode], {
      dateFormat: kivi.myconfig.dateformat.replace(/d+/gi, 'dd').replace(/m+/gi, 'mm').replace(/y+/gi, 'yy'),
      showOn: "button",
      showButtonPanel: true,
      changeMonth: true,
      changeYear: true,
      buttonImage: "image/calendar.png",
      buttonImageOnly: true
  }));

  kivi.setup_formats({
    numbers: kivi.myconfig.numberformat,
    dates:   kivi.myconfig.dateformat,
    times:   kivi.myconfig.timeformat
  });

  kivi.reinit_widgets();

[%- IF ajax_spinner %]
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
