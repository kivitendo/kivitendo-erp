/* Functions used for the requirement specs */

// -----------------------------------------------------------------------------
// ------------------------------ basic settings -------------------------------
// -----------------------------------------------------------------------------

function basic_settings_customer_changed(customer_ctrl, value_ctrl) {
  $.get(
    'controller.pl?action=Customer/get_hourly_rate',
    { id: $(customer_ctrl).val() },
    function(data) { if (data.hourly_rate_formatted) $(value_ctrl).val(data.hourly_rate_formatted); }
  );
}

// -----------------------------------------------------------------------------
// ------------------------------ the tree itself ------------------------------
// -----------------------------------------------------------------------------

function requirement_spec_tree_check_move(data) {
  var dragged_type = data.o.data('type');
  var dropped_type = data.r.data('type');

  // console.debug("dragged " + dragged_type + " dropped " + dropped_type + " dir " + data.p);

  if ((dragged_type == "sections") || (dragged_type == "text-blocks-front") || (dragged_type == "text-blocks-back"))
    return false;

  if (dragged_type == "text-block") {
    if ((dropped_type == "text-blocks-front") || (dropped_type == "text-blocks-back"))
      return (data.p == "inside") || (data.p == "last");
    if (dropped_type == "text-block")
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
  if ((dropped_type == "text-block") || (dropped_type == "text-blocks-front") || (dropped_type == "text-blocks-back"))
    return false;

  var dropped_depth = dropped_type == "sections" ? 0 : dropped_type == "section" ? 1 : data.r.parent().parent().data('type') != "function-block" ? 2 : 3;
  if ((data.p == "inside") || (data.p == "last"))
    dropped_depth++;

  var dragged_depth = 1 + data.o.children('ul').size();

  // console.debug("dropped_depth " + dropped_depth + " dragged_depth " + dragged_depth);

  return (2 <= dropped_depth) && ((dragged_depth + dropped_depth) <= 4);
}

function requirement_spec_tree_node_moved(event) {
  // console.debug("node moved");
  var move_obj   = $.jstree._reference('#tree')._get_move();
  var dragged    = move_obj.o;
  var dropped    = move_obj.r;
  var controller = dragged.data("type") == "text-block" ? "RequirementSpecTextBlock" : "RequirementSpecItem";
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

  var url = 'controller.pl?action='
  $.get('controller.pl', {
    action:               (/^text-block/.test(type) ? 'RequirementSpecTextBlock' : 'RequirementSpecItem') + '/ajax_list.js',
    requirement_spec_id:  $('#requirement_spec_id').val(),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val(),
    clicked_type:         type,
    clicked_id:           node.data('id')
  }, eval_json_result);
}

// -------------------------------------------------------------------------
// ------------------------------ text blocks ------------------------------
// -------------------------------------------------------------------------

function find_text_block_id(clicked_elt) {
  // console.log("id: " + $(clicked_elt).attr('id'));
  var id = $(clicked_elt).attr('id');
  if (/^text-block-\d+$/.test(id)) {
    // console.log("find_text_block_id: case 1: " + id.substr(11));
    return id.substr(11) * 1;
  }

  id = $(clicked_elt).closest("[id*=text-block-]").attr('id')
  if (/^text-block-\d+$/.test(id)) {
    // console.log("find_text_block_id: case 2: " + id.substr(11));
    return id.substr(11) * 1;
  }

  id = $(clicked_elt).closest("[id*=tb-]").attr('id')
  if (/^tb-\d+$/.test(id)) {
    // console.log("find_text_block_id: case 3: " + id.substr(3));
    return id.substr(3) * 1;
  }

  // console.log("find_text_block_id: case undef");
  return undefined;
}

function find_text_block_output_position(clicked_elt) {
  var output_position = $(clicked_elt).closest('#text-block-list-container').find('#text_block_output_position').val();
  if (output_position)
    return output_position;

  var type = $(clicked_elt).closest('#tb-back,#tb-front').data('type');
  if (/^text-blocks-(front|back)/.test(type))
    return type == "text-blocks-front" ? 0 : 1;

  return undefined;
}

function disable_edit_text_block_commands(key, opt) {
  return find_text_block_id(opt.$trigger) == undefined;
}

function standard_text_block_ajax_call(key, opt, other_data) {
  var data = {
    action:               "RequirementSpecTextBlock/ajax_" + key,
    requirement_spec_id:  $('#requirement_spec_id').val(),
    id:                   find_text_block_id(opt.$trigger),
    output_position:      find_text_block_output_position(opt.$trigger),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };

  $.post("controller.pl", $.extend(data, other_data || {}), eval_json_result);

  return true;
}

function submit_edit_text_block_form(id_base) {
  var id   = $('#' + id_base + '_id').val();
  var url  = "controller.pl?" + $('#' + id_base + '_form').serialize();
  var data = {
    action:      'RequirementSpecTextBlock/ajax_' + (id ? 'update' : 'create'),
    id:          id,
    form_prefix: id_base
  };
  $.post(url, data, eval_json_result);
  return true;
}

function cancel_edit_text_block_form(id_base) {
  var id = $('#' + id_base + '_id').val();
  $('#' + id_base + '_form').remove();
  if (id)
    $('#text-block-' + id).show();
}

// --------------------------------------------------------------------------------
// ------------------------------ sections and items ------------------------------
// --------------------------------------------------------------------------------

function find_item_id(clicked_elt) {
  // console.log("clicked id: " + $(clicked_elt).attr('id'));
  var id     = $(clicked_elt).attr('id');
  var result = /^(function-block|function-block-content|sub-function-block|sub-function-block-content|section|section-header)-(\d+)$/.exec(id);
  if (result) {
    // console.log("find_item_id: case 1: " + result[2]);
    return result[2];
  }

  id = $(clicked_elt).closest("[id*=fb-]").attr('id')
  if (/^fb-\d+$/.test(id)) {
    // console.log("find_item_id: case 2: " + id.substr(3));
    return id.substr(3) * 1;
  }

  // console.log("find_item_id: case undef");
  return undefined;
}

function standard_item_ajax_call(key, opt, other_data) {
  var data = {
    action:               "RequirementSpecItem/ajax_" + key,
    requirement_spec_id:  $('#requirement_spec_id').val(),
    id:                   find_item_id(opt.$trigger),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };

  // console.log("I would normally POST the following now:");
  // console.log(data);
  $.post("controller.pl", $.extend(data, other_data || {}), eval_json_result);

  return true;
}

function disable_edit_item_commands(key, opt) {
  return find_item_id(opt.$trigger) == undefined;
}

function disable_add_function_block_command(key, opt) {
  if (find_item_id(opt.$trigger))
    return false;
  return opt.$trigger.attr('id') != "section-list-empty";
}

function submit_edit_item_form(id_base) {
  var id   = $('#' + id_base + '_id').val();
  var url  = "controller.pl?" + $('#' + id_base + '_form').serialize();
  var data = {
    action:      'RequirementSpecItem/ajax_' + (id ? 'update' : 'create'),
    id:          id,
    form_prefix: id_base
  };
  $.post(url, data, eval_json_result);
  return true;
}

function cancel_edit_item_form(form_id_base, options) {
  $('#' + form_id_base + '_form').remove();
  if (!options)
    return;
  if (options.to_show)
    $(options.to_show).show();
  if (options.to_hide_if_empty && (1 == $(options.to_hide_if_empty).children().size()))
    $(options.to_hide_if_empty).hide();
}
