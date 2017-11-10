namespace('kivi.CustomDataExportDesigner', function(ns){
  'use strict';

  ns.enable_default_value = function() {
    var count = $(this).prop('id').replace("default_value_type_", "");
    var type  = $(this).val();
    $('#default_value_' + count).prop('disabled', (type === 'none') || (type === 'current_user_login'));
  };
});

$(function() {
  $('[id^="default_value_type_"]').change(kivi.CustomDataExportDesigner.enable_default_value);
});
