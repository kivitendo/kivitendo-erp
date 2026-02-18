namespace('kivi.SearchProfile', function(ns){
  'use strict';

  ns.validate_for_deleting = function(action) {
    if (($('#SEARCH_PROFILE_OPTIONS_search_profile_id').val() || '') == '') {
      alert(kivi.t8('You must select a profile to delete.'));
      return false;
    }

    if (!confirm(kivi.t8('Are you sure?')))
      return false;

    $('#action').val(action);

    return true;
  };

  ns.validate_for_saving = function(action) {
    if (($('#SEARCH_PROFILE_OPTIONS_name').val() || '') == '') {
      alert(kivi.t8('You must enter a name for the search profile.'));
      return false;
    }

    $('#action').val(action);

    return true;
  };
});
