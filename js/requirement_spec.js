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

function cancel_edit_text_block_form(id_base) {
  var id = $('#' + id_base + '_id').val();
  $('#' + id_base + '_form').remove();
  if (id)
    $('#text-block-' + id).show();
}

function ask_delete_text_block(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    standard_text_block_ajax_call(key, opt);
  return true;
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

function cancel_edit_item_form(form_id_base, options) {
  $('#' + form_id_base + '_form').remove();
  if (!options)
    return;
  if (options.to_show)
    $(options.to_show).show();
  if (options.to_hide_if_empty && (1 == $(options.to_hide_if_empty).children().size()))
    $(options.to_hide_if_empty).hide();
}

function ask_delete_item(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    standard_item_ajax_call(key, opt);
  return true;
}

function handle_text_block_popup_menu_markings(opt, add) {
  var id = find_text_block_id(opt.$trigger);
  if (id)
    $('#text-block-' + id).toggleClass('selected', add);
  return true;
}

function requirement_spec_text_block_popup_menu_shown(opt) {
  return handle_text_block_popup_menu_markings(opt, true);
}

function requirement_spec_text_block_popup_menu_hidden(opt) {
  return handle_text_block_popup_menu_markings(opt, false);
}

function handle_item_popup_menu_markings(opt, add) {
  var id = find_item_id(opt.$trigger);
  if (id)
    $('#section-' + id + ',#function-block-' + id + ',#sub-function-block-' + id).toggleClass('selected', add);
  return true;
}

function requirement_spec_item_popup_menu_shown(opt) {
  return handle_item_popup_menu_markings(opt, true);
}

function requirement_spec_item_popup_menu_hidden(opt) {
  return handle_item_popup_menu_markings(opt, false);
}

// -------------------------------------------------------------------------
// -------------------------- time/cost estimate ---------------------------
// -------------------------------------------------------------------------

function standard_time_cost_estimate_ajax_call(key, opt) {
  if ((key == 'cancel') && !confirm(kivi.t8('Do you really want to cancel?')))
    return true;

  var data = "action=RequirementSpec/ajax_" + key + "_time_and_cost_estimate&";

  if (key == 'save')
    data += $('#edit_time_cost_estimate_form').serialize()
         +  '&' + $('#current_content_type').serialize()
         +  '&' + $('#current_content_id').serialize();
  else
    data += 'id=' + encodeURIComponent($('#requirement_spec_id').val());

  $.post("controller.pl", data, eval_json_result);

  return true;
}

// -------------------------------------------------------------------------
// ---------------------------- general actions ----------------------------
// -------------------------------------------------------------------------

function download_reqspec_pdf(key, opt) {
  var data = {
    action: "RequirementSpec/download_pdf",
    id:     $('#requirement_spec_id').val()
  };
  $.download("controller.pl", data);
}

function copy_reqspec(key, opt) {
  window.location.href = "controller.pl?action=RequirementSpec/new&copy_source_id=" + encodeURIComponent($('#requirement_spec_id').val());
  return true;
}

function delete_reqspec(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    window.location.href = "controller.pl?action=RequirementSpec/destroy&id=" + encodeURIComponent($('#requirement_spec_id').val());
  return true;
}

function disable_requirement_spec_commands(key, opt) {
  if (key === "create_version")
    return ($('#current_version_id').val() || '') == '' ? false : true;
  return false;
}

// -------------------------------------------------------------------------
// -------------------------------- versions -------------------------------
// -------------------------------------------------------------------------

function find_versioned_copy_id(clicked_elt) {
  var id = $(clicked_elt).find("[name=versioned_copy_id]");
  return id ? id.val() : undefined;
}

function disable_versioned_copy_item_commands(key, opt) {
  if (key === "revert_to_version")
    return !find_versioned_copy_id(opt.$trigger);
  return false;
}

function create_requirement_spec_version() {
  open_jqm_window({ url:  'controller.pl',
                    data: { action:              'RequirementSpecVersion/new',
                            requirement_spec_id: $('#requirement_spec_id').val() },
                    id:   'new_requirement_spec_version_window' });
  return true;
}

function create_pdf_for_versioned_copy_ajax_call(key, opt) {
  // TODO: create_pdf_for_versioned_copy_ajax_call

  return true;
}

function revert_to_versioned_copy_ajax_call(key, opt) {
  if (!confirm(kivi.t8('Do you really want to revert to this version?')))
    return true;

  var data = {
    action:            'RequirementSpec/revert_to',
    versioned_copy_id: find_versioned_copy_id(opt.$trigger),
    id:                $('#requirement_spec_id').val()
  };

  $.post("controller.pl", data, eval_json_result);

  return true;
}

// -------------------------------------------------------------------------
// ----------------------------- context menus -----------------------------
// -------------------------------------------------------------------------

function create_requirement_spec_context_menus() {
  var general_actions = {
      sep98:           "---------"
    , general_actions: { name: kivi.t8('Requirement spec actions:') }
    , sep99:           "---------"
    , create_version:  { name: kivi.t8('Create new version'),      icon: "new",    callback: create_requirement_spec_version, disabled: disable_requirement_spec_commands }
    , copy_reqspec:    { name: kivi.t8('Copy requirement spec'),   icon: "copy",   callback: copy_reqspec   }
    , delete_reqspec:  { name: kivi.t8('Delete requirement spec'), icon: "delete", callback: delete_reqspec }
  };

  $.contextMenu({
    selector: '#content',
    items:    general_actions
  });

  var events = {
    show: requirement_spec_text_block_popup_menu_shown,
    hide: requirement_spec_text_block_popup_menu_hidden
  };

  $.contextMenu({
    selector: '.text-block-context-menu',
    events:   {
        show: requirement_spec_text_block_popup_menu_shown
      , hide: requirement_spec_text_block_popup_menu_hidden
    },
    items:    $.extend({
        add:     { name: kivi.t8('Add text block'),        icon: "add",    callback: standard_text_block_ajax_call }
      , edit:    { name: kivi.t8('Edit text block'),       icon: "edit",   callback: standard_text_block_ajax_call, disabled: disable_edit_text_block_commands }
      , delete:  { name: kivi.t8('Delete text block'),     icon: "delete", callback: ask_delete_text_block,         disabled: disable_edit_text_block_commands }
      , sep1:    "---------"
      , flag:    { name: kivi.t8('Toggle marker'),         icon: "flag",   callback: standard_text_block_ajax_call, disabled: disable_edit_text_block_commands }
      , sep2:    "---------"
      , copy:    { name: kivi.t8('Copy'),                  icon: "copy",   callback: standard_text_block_ajax_call, disabled: disable_edit_text_block_commands }
      , paste:   { name: kivi.t8('Paste'),                 icon: "paste",  callback: standard_text_block_ajax_call  }
    }, general_actions)
  });

  events = {
    show: requirement_spec_item_popup_menu_shown,
    hide: requirement_spec_item_popup_menu_hidden
  };

  $.contextMenu({
    selector: '.section-context-menu',
    events:   events,
    items:    $.extend({
        add_section:        { name: kivi.t8('Add section'),        icon: "add",    callback: standard_item_ajax_call }
      , add_function_block: { name: kivi.t8('Add function block'), icon: "add",    callback: standard_item_ajax_call, disabled: disable_add_function_block_command }
      , sep1:               "---------"
      , edit:               { name: kivi.t8('Edit'),               icon: "edit",   callback: standard_item_ajax_call, disabled: disable_edit_item_commands }
      , delete:             { name: kivi.t8('Delete'),             icon: "delete", callback: ask_delete_item,         disabled: disable_edit_item_commands }
      , sep2:               "---------"
      , flag:               { name: kivi.t8('Toggle marker'),      icon: "flag",   callback: standard_item_ajax_call, disabled: disable_edit_item_commands }
      , sep3:               "---------"
      , copy:               { name: kivi.t8('Copy'),               icon: "copy",   callback: standard_item_ajax_call, disabled: disable_edit_item_commands }
      , paste:              { name: kivi.t8('Paste'),              icon: "paste",  callback: standard_item_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.function-block-context-menu,.sub-function-block-context-menu',
    events:   events,
    items:    $.extend({
        add_function_block:     { name: kivi.t8('Add function block'),     icon: "add",    callback: standard_item_ajax_call }
      , add_sub_function_block: { name: kivi.t8('Add sub function block'), icon: "add",    callback: standard_item_ajax_call }
      , sep1:                   "---------"
      , edit:                   { name: kivi.t8('Edit'),                   icon: "edit",   callback: standard_item_ajax_call, disabled: disable_edit_item_commands }
      , delete:                 { name: kivi.t8('Delete'),                 icon: "delete", callback: ask_delete_item,         disabled: disable_edit_item_commands }
      , sep2:                   "---------"
      , flag:                   { name: kivi.t8('Toggle marker'),          icon: "flag",   callback: standard_item_ajax_call, disabled: disable_edit_item_commands }
      , sep3:                   "---------"
      , copy:                   { name: kivi.t8('Copy'),                   icon: "copy",   callback: standard_item_ajax_call, disabled: disable_edit_item_commands }
      , paste:                  { name: kivi.t8('Paste'),                  icon: "paste",  callback: standard_item_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.time-cost-estimate-context-menu',
    items:    $.extend({ edit: { name: kivi.t8('Edit'), icon: "edit", callback: standard_time_cost_estimate_ajax_call } }, general_actions)
  });

  $.contextMenu({
    selector: '.edit-time-cost-estimate-context-menu',
    items:    $.extend({
        save:   { name: kivi.t8('Save'),   icon: "save",  callback: standard_time_cost_estimate_ajax_call }
      , cancel: { name: kivi.t8('Cancel'), icon: "close", callback: standard_time_cost_estimate_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.versioned-copy-context-menu',
    items:    $.extend({
        // create_pdf:        { name: kivi.t8('Create PDF'),        icon: "pdf",    callback: create_pdf_for_versioned_copy_ajax_call                                                }
      revert_to_version: { name: kivi.t8('Revert to version'), icon: "revert", callback: revert_to_versioned_copy_ajax_call,     disabled: disable_versioned_copy_item_commands }
    }, general_actions)
  });
}
