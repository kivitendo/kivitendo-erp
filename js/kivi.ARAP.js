namespace('kivi.ARAP', function(ns){
  'use strict';

  ns.toggle_form_details = function() {
    if ($('.second_row').is(':visible')) {
      $('.second_row').hide();
      $('#details_button').html(kivi.t8('Show details'));
    } else {
      $('.second_row').show();
      $('#details_button').html(kivi.t8('Hide details'));
    }
  };

});
