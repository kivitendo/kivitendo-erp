/* Functions used for the requirement specs tree view */

function requirement_spec_tree_check_move(data) {
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

function requirement_spec_tree_node_moved(event) {
  console.debug("node moved");
  var move_obj   = $.jstree._reference('#tree')._get_move();
  var dragged    = move_obj.o;
  var dropped    = move_obj.r;
  var controller = dragged.data("type") == "textblock" ? "RequirementSpecTextBlock" : "RequirementSpecItem";
  var data       = {
    action:               controller + "/dragged_and_dropped",
    requirement_spec_id:  $('#requirement_spec_id').val(),
    id:                   dragged.data("id"),
    dropped_id:           dropped.data("id"),
    dropped_type:         dropped.data("type"),
    position:             move_obj.p,
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };
  // console.debug("controller: " + controller);
  // console.debug(data);

  $.post("controller.pl", data, eval_json_result);

  return true;
}

function requirement_spec_tree_node_clicked(event) {
  var node = $.jstree._reference('#tree')._get_node(event.target);
  var type = node ? node.data('type') : undefined;

  if (!type)
    return;

  if ('sections' ==  type) {
    $('#current_content_type').val('sections');
    $('#current_content_id').val('');
    return;
  }

  var url = 'controller.pl?action='
  $.get('controller.pl', {
    action:               (/^textblock/ ? 'RequirementSpecTextBlock' : 'RequirementSpecItem') + '/ajax_list.js',
    requirement_spec_id:  $('#requirement_spec_id').val(),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val(),
    clicked_type:         type,
    clicked_id:           node.data('id')
  }, function(new_data) {
    $('#current_content_type').val(type);
    $('#current_content_id').val(node.data('id'));
    eval_json_result(new_data);
  });
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

function find_text_block_id(clicked_elt) {
  console.log("id: " + $(clicked_elt).attr('id'));
  var id = $(clicked_elt).attr('id');
  if (/^text-block-\d+$/.test(id)) {
    console.log("find_text_block_id: case 1: " + id.substr(11));
    return id.substr(11) * 1;
  }

  id = $(clicked_elt).closest("[id*=text-block-]").attr('id')
  if (/^text-block-\d+$/.test(id)) {
    console.log("find_text_block_id: case 2: " + id.substr(11));
    return id.substr(11) * 1;
  }

  id = $(clicked_elt).closest("[id*=tb-]").attr('id')
  if (/^tb-\d+$/.test(id)) {
    console.log("find_text_block_id: case 3: " + id.substr(3));
    return id.substr(3) * 1;
  }

  console.log("find_text_block_id: case undef");
  return undefined;
}

function find_text_block_output_position(clicked_elt) {
  var output_position = $(clicked_elt).closest('#text-block-list-container').find('#text_block_output_position').val();
  if (output_position)
    return output_position;

  var type = $(clicked_elt).closest('#tb-back,#tb-front').data('type');
  if (/^textblocks-(front|back)/.test(type))
    return type == "textblocks-front" ? 0 : 1;

  return undefined;
}

function disable_edit_text_block_commands(key, opt) {
  return find_text_block_id(opt.$trigger) == undefined;
}

function edit_text_block(key, opt) {
  var data = {
    action:               "RequirementSpecTextBlock/ajax_edit",
    id:                   find_text_block_id(opt.$trigger),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };
  $.post("controller.pl", data, eval_json_result);
  return true;
}

function add_text_block(key, opt) {
  return true;
}

function delete_text_block(key, opt) {
  var data = {
    action:               "RequirementSpecTextBlock/ajax_delete",
    id:                   find_text_block_id(opt.$trigger),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };
  $.post("controller.pl", data, eval_json_result);
  return true;
}

function submit_edit_text_block_form(id_base) {
  var url  = "controller.pl?" + $('#' + id_base + '_form').serialize();
  var data = {
    action:      'RequirementSpecTextBlock/ajax_update',
    id:          $('#' + id_base + '_id').val(),
    form_prefix: id_base
  };
  console.log("posting edit text block: " + url);
  console.log(data);
  $.post(url, data, eval_json_result);
}

function cancel_edit_text_block_form(id_base) {
  var id = $('#' + id_base + '_id').val();
  $('#' + id_base + '_form').remove();
  if (id)
    $('#text-block-' + id).show();
}
