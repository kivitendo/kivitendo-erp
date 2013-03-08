/* Functions used for the requirement specs tree view */

function check_move(data) {
  var dragged_type = data.o.data('type');
  var dropped_type = data.r.data('type');

  // console.debug("dragged " + dragged_type + " dropped " + dropped_type + " dir " + data.p);

  if ((dragged_type == "sections") || (dragged_type == "textblocks-front") || (dragged_type == "textblocks-back"))
    return false;

  if (dragged_type == "textblock") {
    if ((dropped_type == "textblocks-front") || (dropped_type == "textblocks-back"))
      return (data.p == "inside") || (data.p == "last");
    if (dropped_type == "textblock")
      return (data.p == "before") || (data.p == "after");

    return false;
  }

  if (dragged_type == "section") {
    if (dropped_type == "sections")
      return (data.p == "inside") || (data.p == "last");
    if (dropped_type == "section")
      return (data.p == "before") || (data.p == "after");

    return false;
  }

  // dragged_type == (sub) function blocks
  if ((dropped_type == "textblock") || (dropped_type == "textblocks-front") || (dropped_type == "textblocks-back"))
    return false;

  var dropped_depth = dropped_type == "sections" ? 0 : dropped_type == "section" ? 1 : data.r.parent().parent().data('type') != "functionblock" ? 2 : 3;
  if ((data.p == "inside") || (data.p == "last"))
    dropped_depth++;

  var dragged_depth = 1 + data.o.children('ul').size();

  // console.debug("dropped_depth " + dropped_depth + " dragged_depth " + dragged_depth);

  return (2 <= dropped_depth) && ((dragged_depth + dropped_depth) <= 4);
}

function node_moved(event) {
  console.debug("node moved");
  var move_obj   = $.jstree._reference('#tree')._get_move();
  var dragged    = move_obj.o;
  var dropped    = move_obj.r;
  var controller = dragged.data("type") == "textblock" ? "RequirementSpecTextBlock" : "RequirementSpecItem";
  var data       = {
    action:              controller + "/dragged_and_dropped",
    requirement_spec_id: $('#requirement_spec_id').val(),
    id:                  dragged.data("id"),
    dropped_id:          dropped.data("id"),
    dropped_type:        dropped.data("type"),
    position:            move_obj.p
  };
  // console.debug("controller: " + controller);
  // console.debug(data);

  $.ajax({ url: "controller.pl", data: data });
}

function section_form_requested(data) {
  $('#new-section-button').removeAttr('disabled');
  if (data.status == "ok")
    $('#content-column').html(data.html);
  else
    alert('oh yeah response: ' + data.status + "\n" + data.error);
}

function section_form_submitted(data) {
  alert('oh yeah response: ' + data.status);
}

function server_side_error(things_to_enable) {
  alert('Server-side error.');
  if (things_to_enable)
    $(things_to_enable).removeAttr('disabled');
}

function new_section_form() {
  $('#new-section-button').attr('disabled', 'disabled');
  $.ajax({
    type: 'POST',
    url: 'controller.pl',
    data: 'action=RequirementSpecItem/new.json&requirement_spec_id=' + $('#requirement_spec_id').val() + '&item_type=section',
    success: section_form_requested,
    error: function() { server_side_error('#new-section-button'); }
  });
}

function submit_section_form(id) {
  $.ajax({
    type: 'POST',
    url: 'controller.pl',
    data: 'action=RequirementSpecItem/create.json&' + $('section-form-' + id).serialize(),
    success: section_form_submitted
  });
}

function cancel_section_form(id) {
  $('#content-column').html('intentionally empty');
}
