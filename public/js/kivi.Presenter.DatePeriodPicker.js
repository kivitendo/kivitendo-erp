namespace('kivi.ReportPeriod', function(ns) {

  ns.open_dialog = function(el) {

    ns.current_id = el.parentNode.id;

    ns.current_dialog = $(`#${ ns.current_id }_preset_dialog`).dialog({
      title: kivi.t8('Select from preset'),
      width:  340,
      height: 330,
      modal: true,
    });
  }

  ns.apply_preset = function() {

    const year = $(`#${ ns.current_id }_preset_dialog_year`).val();
    const type = $(`input[name="${ ns.current_id }_preset_dialog_type"]:checked`).val();
    const quarter = $(`#${ ns.current_id }_preset_dialog_quarter`).val();
    const month = $(`#${ ns.current_id }_preset_dialog_month`).val();

    let duetyp = 13; // (yearly)
    if (type === 'quarterly') {
      duetyp = quarter;
    } else if (type === 'monthly') {
      duetyp = month;
    }
    ns.set_from_to(duetyp, year);

    $(`#${ ns.current_id }_selected_preset_year`).val(year);
    $(`#${ ns.current_id }_selected_preset_type`).val(type);
    $(`#${ ns.current_id }_selected_preset_quarter`).val(quarter);
    $(`#${ ns.current_id }_selected_preset_month`).val(month);

    ns.current_dialog.dialog('close');
    $(`#${ ns.current_id }_preset_dialog_button`)
  }

  ns.set_from_to = function (duetyp, year) {
    const date = {
      1:  [ 1,  1, 1,  31 ],
      2:  [ 2,  1, 2,  new Date(year, 1, 29).getMonth() == 1 ? 29 : 28 ],
      3:  [ 3,  1, 3,  31 ],
      4:  [ 4,  1, 4,  30 ],
      5:  [ 5,  1, 5,  31 ],
      6:  [ 6,  1, 6,  30 ],
      7:  [ 7,  1, 7,  31 ],
      8:  [ 8,  1, 8,  31 ],
      9:  [ 9,  1, 9,  30 ],
      10: [ 10, 1, 10, 31 ],
      11: [ 11, 1, 11, 30 ],
      12: [ 12, 1, 12, 31 ],
      13: [  1, 1, 12, 31 ],
      'A': [ 1,  1, 3,  31 ],
      'B': [ 4,  1, 6,  30 ],
      'C': [ 7,  1, 9,  30 ],
      'D': [ 10, 1, 12, 31 ]
    }[duetyp];

    $(`#${ ns.current_id }_from_date`).val(kivi.format_date(new Date(year, date[0]-1, date[1])));
    $(`#${ ns.current_id }_to_date`).val(kivi.format_date(new Date(year, date[2]-1, date[3])));
  }
});