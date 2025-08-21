namespace('kivi.PartsGroup', function(ns) {
  ns.move_parts_to_partsgroup = function() {
    var data = $('#parts_form').serializeArray();
    data.push({ name: 'current_partsgroup_id',  value: '[% SELF.partsgroup.id %]' });
    data.push({ name: 'selected_partsgroup_id', value: $("#selected_partsgroup").val() });
    data.push({ name: 'action',                   value: 'PartsGroup/update_partsgroup_for_parts' });
    $.post("controller.pl", data, kivi.eval_json_result);
  };
  ns.add_part = function() {
    var data = {
      action:        'PartsGroup/add_part',
      part_id:       $('#add_part_id').val(),
      partsgroup_id: $('#id').val()
    };
    $.post("controller.pl", data, kivi.eval_json_result);
  };
  ns.add_partsgroup = function() {
    var data = {
      action:          'PartsGroup/add_partsgroup',
      parent_id:       $('#id').val(),
      partsgroup_name: $('#new_partsgroup').val()
    };
    $.post("controller.pl", data, kivi.eval_json_result);
  };
});
