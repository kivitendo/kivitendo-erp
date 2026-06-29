/* Functions used for the requirement specs */

namespace("kivi.requirement_spec", function(ns) {

// -----------------------------------------------------------------------------
// ------------------------------ basic settings -------------------------------
// -----------------------------------------------------------------------------

ns.basic_settings_customer_changed = function(customer_ctrl, value_ctrl) {
  $.get(
    'controller.pl?action=Customer/get_hourly_rate',
    { id: $(customer_ctrl).val() },
    function(data) { if (data.hourly_rate_formatted) $(value_ctrl).val(data.hourly_rate_formatted); }
  );
};

// -----------------------------------------------------------------------------
// ------------------------------ the tree itself ------------------------------
// -----------------------------------------------------------------------------

ns.tree_check_move = function(data) {
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
};

ns.tree_node_moved = function(event) {
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

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.tree_node_clicked = function(event) {
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
  }, kivi.eval_json_result);
};

ns.setup_tooltip_for_tree_node = function(li) {
  $(li).find('a').prop('title', $(li).prop('title')).tooltip();
  $(li).prop('title', '');
};

ns.tree_loaded = function(event) {
  var id = $('#tree').data('initially_selected_node');
  if (id)
    $.jstree._reference("#tree").select_node(id, true);

  $('#tree li[title!=""]').each(function(idx, elt) {
    ns.setup_tooltip_for_tree_node(elt);
  });
};

ns.tree_node_created = function(event, data) {
  console.info("created ", data);
  if (data && data.rslt && data.rslt.obj)
    ns.setup_tooltip_for_tree_node(data.rslt.obj);
};

ns.initialize_requirement_spec = function(data) {
  $('#tree').data('initially_selected_node', data.initially_selected_node);

  $('#tree')
    .bind('create_node.jstree', ns.tree_node_created)
    .bind('move_node.jstree',   ns.tree_node_moved)
    .bind('click.jstree',       ns.tree_node_clicked)
    .bind('loaded.jstree',      ns.tree_loaded)
    .jstree({
      core: {
        animation: 0,
        initially_open: data.initially_open,
      },
      json_data: {
        data: data.tree_data
      },
      crrm: {
        move: {
          check_move: ns.tree_check_move,
          open_move:  true
        }
      },
      themes: {
        theme: "requirement-spec"
      },
      plugins: [ "themes", "json_data", "ui", "crrm", "dnd" ]
    });

  ns.create_context_menus(data);
  $('#requirement_spec_tabs').on("tabsbeforeactivate", ns.tabs_before_activate);

  ns.time_based_units = data.time_based_units;
};

// -------------------------------------------------------------------------
// ------------------------------ text blocks ------------------------------
// -------------------------------------------------------------------------

ns.find_text_block_id = function(clicked_elt) {
  var id = $(clicked_elt).attr('id');

  if (/^text-block-picture-\d+$/.test(id))
    id = $(clicked_elt).closest('.text-block-context-menu').attr('id');

  // console.log("id: " + id);
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

  // console.log("find_text_block_id: case undef, id: " + id);
  return undefined;
};

ns.find_text_block_output_position = function(clicked_elt) {
  var output_position = $(clicked_elt).closest('#text-block-list-container').find('#text_block_output_position').val();
  if (output_position)
    return output_position;

  var type = $(clicked_elt).closest('#tb-back,#tb-front').data('type') || $('#current_content_type').val();
  if (/^text-blocks-(front|back)/.test(type))
    return type == "text-blocks-front" ? 0 : 1;

  return undefined;
};

ns.disable_edit_text_block_commands = function(key, opt) {
  return ns.find_text_block_id(opt.$trigger) == undefined;
};

ns.standard_text_block_ajax_call = function(key, opt, other_data) {
  var data = {
    action:               "RequirementSpecTextBlock/ajax_" + key,
    requirement_spec_id:  $('#requirement_spec_id').val(),
    id:                   ns.find_text_block_id(opt.$trigger),
    output_position:      ns.find_text_block_output_position(opt.$trigger),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };

  $.post("controller.pl", $.extend(data, other_data || {}), kivi.eval_json_result);

  return true;
};

ns.cancel_edit_text_block_form = function(id_base) {
  var id = $('#' + id_base + '_id').val();
  $('#' + id_base + '_form').remove();
  if (id)
    $('#text-block-' + id).show();
};

ns.ask_delete_text_block = function(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    ns.standard_text_block_ajax_call(key, opt);
  return true;
};

ns.find_text_block_picture_id = function(clicked_elt) {
  var id    = $(clicked_elt).attr('id');
  var match = id.match(/^text-block-picture-(\d+)$/);
  if (match)
    return match[1] * 1;

  return undefined;
};

ns.add_edit_text_block_picture_ajax_call = function(key, opt) {
  var title = key == 'add_picture' ? kivi.t8('Add picture to text block') : kivi.t8('Edit picture');

  kivi.popup_dialog({ url:    'controller.pl',
                      data:   { action:     'RequirementSpecTextBlock/ajax_' + key,
                                id:         ns.find_text_block_id(opt.$trigger),
                                picture_id: ns.find_text_block_picture_id(opt.$trigger) },
                      dialog: { title:      title }});

  return true;
};

ns.standard_text_block_picture_ajax_call = function(key, opt) {
  var data = {
      action: "RequirementSpecTextBlock/ajax_" + key
    , id:     ns.find_text_block_picture_id(opt.$trigger)
  };

  if (key == 'download_picture')
    $.download("controller.pl", data);
  else
    $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.ask_delete_text_block_picture = function(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    ns.standard_text_block_picture_ajax_call(key, opt);
  return true;
};

ns.handle_text_block_picture_popup_menu_markings = function(opt, add) {
  var id = ns.find_text_block_picture_id(opt.$trigger);
  if (id)
    $('#text-block-picture-' + id ).toggleClass('selected', add);
  return true;
};

ns.text_block_picture_popup_menu_shown = function(opt) {
  return ns.handle_text_block_picture_popup_menu_markings(opt, true);
};

ns.text_block_picture_popup_menu_hidden = function(opt) {
  return ns.handle_text_block_picture_popup_menu_markings(opt, false);
};

ns.make_text_block_picture_lists_sortable = function() {
  kivi.run_once_for(".requirement-spec-text-block-picture-list", 'make-text-block-picture-list-sortable', function($elt) {
    $elt.sortable({
      stop: function(event, ui) {
        $.post('controller.pl?action=RequirementSpecTextBlock/reorder_pictures', {
          'picture_id[]': $($elt.sortable('toArray')).map(function(idx, str) { return str.replace('text-block-picture-', ''); }).toArray()
        });
        return ui;
      }
      , distance: 5
    });
  });
};

// --------------------------------------------------------------------------------
// ------------------------------ sections and items ------------------------------
// --------------------------------------------------------------------------------

ns.find_item_id = function(clicked_elt) {
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
};

ns.standard_item_ajax_call = function(key, opt, other_data) {
  var data = {
    action:               "RequirementSpecItem/ajax_" + key,
    requirement_spec_id:  $('#requirement_spec_id').val(),
    id:                   ns.find_item_id(opt.$trigger),
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };

  // console.log("I would normally POST the following now:");
  // console.log(data);
  $.post("controller.pl", $.extend(data, other_data || {}), kivi.eval_json_result);

  return true;
};

ns.disable_edit_item_commands = function(key, opt) {
  return ns.find_item_id(opt.$trigger) == undefined;
};

ns.disable_add_function_block_command = function(key, opt) {
  return opt.$trigger.attr('id') == "sections";
};

ns.cancel_edit_item_form = function(form_id_base, options) {
  $('#' + form_id_base + '_form').remove();
  if (!options)
    return;
  if (options.to_show)
    $(options.to_show).show();
  if (options.to_hide_if_empty && (1 == $(options.to_hide_if_empty).children().size()))
    $(options.to_hide_if_empty).hide();
};

ns.ask_delete_item = function(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    ns.standard_item_ajax_call(key, opt);
  return true;
};

ns.handle_text_block_popup_menu_markings = function(opt, add) {
  var id = ns.find_text_block_id(opt.$trigger);
  if (id)
    $('#text-block-' + id).toggleClass('selected', add);
  return true;
};

ns.text_block_popup_menu_shown = function(opt) {
  return ns.handle_text_block_popup_menu_markings(opt, true);
};

ns.text_block_popup_menu_hidden = function(opt) {
  return ns.handle_text_block_popup_menu_markings(opt, false);
};

ns.handle_item_popup_menu_markings = function(opt, add) {
  var id = ns.find_item_id(opt.$trigger);
  if (id)
    $('#section-' + id + ',#function-block-' + id + ',#sub-function-block-' + id).toggleClass('selected', add);
  return true;
};

ns.item_popup_menu_shown = function(opt) {
  return ns.handle_item_popup_menu_markings(opt, true);
};

ns.item_popup_menu_hidden = function(opt) {
  return ns.handle_item_popup_menu_markings(opt, false);
};

ns.submit_function_block = function(event, shift_in_out) {
  event.preventDefault();

  var prefix = $(this).attr('id').match("^(?:edit|new)_function_block_[\\d_]+\\d")[0];
  var action = $('#' + prefix + '_id').val() ? 'update' : 'create';
  kivi.submit_ajax_form('controller.pl?action=RequirementSpecItem/ajax_' + action, '#' + prefix + '_form', { shift_in_out: !!shift_in_out });

  return false;
};

ns.init_function_block_keypress_events = function(form_id) {
  $("#" + form_id + " INPUT[type=text]").bind("keypress", "return", ns.submit_function_block);

  $('#' + form_id + ' INPUT[type=text],#' + form_id + ' TEXTAREA,#' + form_id + ' INPUT[type=button]')
    .bind('keypress', 'shift+return', function(event) { return ns.submit_function_block.apply(this, [ event, true ]); });
};

ns.renumber_callback = function(accepted) {
  console.log(accepted ? "yay :)" : "oh no :(");
  if (!accepted)
    return;

  $.ajax({
    url:     'controller.pl?action=RequirementSpec/renumber_sections',
    type:    'post',
    data:    { id: $('#requirement_spec_id').val() },
    success: kivi.eval_json_result
  });
};

ns.renumber = function(opt) {
  $('#rs-dialog-confirm').remove();

  var text1   = kivi.t8('Re-numbering all sections and function blocks in the order they are currently shown cannot be undone.');
  var text2   = kivi.t8('Do you really want to continue?');
  var $dialog = $('<div id="rs-dialog-confirm"><p>' + text1 + '</p><p>' + text2 + '</p></div>').hide().appendTo('body');
  var buttons = {};

  buttons[kivi.t8('Yes')] = function() {
    $(this).dialog('close');
    ns.renumber_callback(true);
  };

  buttons[kivi.t8('No')] = function() {
    $(this).dialog('close');
    ns.renumber_callback(false);
  };

  $dialog.dialog({
      resizable: false
    , modal:     true
    , title:     kivi.t8('Are you sure?')
    , height:    250
    , width:     400
    , buttons:   buttons
  });
};

// -------------------------------------------------------------------------
// ------------------------------- templates -------------------------------
// -------------------------------------------------------------------------

ns.paste_template = function(key, opt, other_data) {
  kivi.popup_dialog({ url: 'controller.pl?action=RequirementSpec/select_template_to_paste', dialog: { title: kivi.t8("Select template to paste") } });
};

ns.paste_selected_template = function(template_id) {
  $('#jqueryui_popup_dialog').dialog("close");

  var data = {
    action:               "RequirementSpec/paste_template",
    id:                   $('#requirement_spec_id').val(),
    template_id:          template_id,
    current_content_type: $('#current_content_type').val(),
    current_content_id:   $('#current_content_id').val()
  };

  // console.log("I would normally POST the following now:");
  // console.log(data);
  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

// -------------------------------------------------------------------------
// ---------------------------- basic settings -----------------------------
// -------------------------------------------------------------------------
ns.standard_basic_settings_ajax_call = function(key, opt) {
  if (key == 'cancel') {
    if (confirm(kivi.t8('Do you really want to cancel?'))) {
      $('#basic_settings').show();
      $('#basic_settings_form,#project_link_form').remove();
    }
    return true;

  } else if (key == 'save') {
    $('#basic_settings_form_submit').click();
    return true;
  }

  var data = 'action=RequirementSpec/ajax_' + key + '&id=' + encodeURIComponent($('#requirement_spec_id').val());

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

// -------------------------------------------------------------------------
// -------------------------- time/cost estimate ---------------------------
// -------------------------------------------------------------------------

ns.standard_time_cost_estimate_ajax_call = function(key, opt) {
  if (key == 'cancel') {
    if (confirm(kivi.t8('Do you really want to cancel?'))) {
      $('#time_cost_estimate').show();
      $('#time_cost_estimate_form_container').remove();
    }
    return true;
  }

  var add_data = '';
  if (key == 'save_keep_open') {
    key      = 'save';
    add_data = 'keep_open=1&';
  }

  var data = "action=RequirementSpec/ajax_" + key + "_time_and_cost_estimate&" + add_data;

  if (key == 'save')
    data += $('#edit_time_cost_estimate_form').serialize()
         +  '&' + $('#current_content_type').serialize()
         +  '&' + $('#current_content_id').serialize();
  else
    data += 'id=' + encodeURIComponent($('#requirement_spec_id').val());

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.time_cost_estimate_input_key_down = function(event) {
  if(event.keyCode == 13) {
    event.preventDefault();
    ns.standard_time_cost_estimate_ajax_call('save');
    return false;
  }
};

// -------------------------------------------------------------------------
// --------------------------- quotations/orders ---------------------------
// -------------------------------------------------------------------------

ns.find_quotation_order_id = function(clicked_elt) {
  return $(clicked_elt).find('>[name=order_id]').val();
};

ns.standard_quotation_order_ajax_call = function(key, opt) {
  if (key == 'cancel') {
    if (confirm(kivi.t8('Do you really want to cancel?'))) {
      $('#quotations_and_orders').show();
      $('#quotations_and_orders_article_assignment,#quotations_and_orders_new,#quotations_and_orders_update').remove();
    }
    return true;
  }

  else if ((key == 'create') && $('#quotations_and_orders_form INPUT[name="sections[].order_part_id"]').filter(function(idx, elt) { return ($(elt).val() || '') == '' }).size()) {
    alert(kivi.t8('There is one or more sections for which no part has been assigned yet; therefore creating the new record is not possible yet.'));
    return false;
  }

  var data = 'action=RequirementSpecOrder/' + key
           + '&' + $('#requirement_spec_id').serialize();

  if ((key == 'save_assignment') || (key == 'create') || (key == 'do_update'))
    data += '&' + $('#quotations_and_orders_form').serialize();
  else if ((key == 'update') || (key == 'delete'))
    data += '&rs_order_id=' + encodeURIComponent(ns.find_quotation_order_id(opt.$trigger));

  // console.log("I would normally POST the following now:");
  // console.log(data);
  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.ask_delete_quotation_order = function(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    ns.standard_quotation_order_ajax_call(key, opt);
  return true;
};

ns.disable_edit_quotation_order_commands = function(key, opt) {
  return ns.find_quotation_order_id(opt.$trigger) == undefined;
};

ns.disable_create_quotation_order_commands = function(key, opt) {
  return !$('#quotations_and_orders_sections');
};

ns.assign_order_part_id_to_all = function() {
  var order_part_id   = $('#quotations_and_orders_order_id').val();
  var order_part_name = $('#quotations_and_orders_order_id_name').val();

  $('#quotations_and_orders_form INPUT[name="sections[].order_part_id"]').each(function(idx, elt) {
    $(elt).val(order_part_id);
  });

  $('#quotations_and_orders_form [id^=quotations_and_orders_sections_order_pard_id_]').filter(function() {
    return $(this).attr('id') && $(this).attr('id').match("^quotations_and_orders_sections_order_pard_id_[0-9]+_name$");
  }).each(function(idx, elt) {
    $(elt).val(order_part_name);
  });

  var unit = $('#quotations_and_orders_order_id').closest('td').data('unit');
  var text = ns.time_based_units[unit] ? kivi.t8("time and effort based position") : kivi.t8("flat-rate position");

  $('#quotations_and_orders_form [data-unit-column=1]').html(unit);
  $('#quotations_and_orders_form [data-position-type-column=1]').html(text);
};

ns.assign_order_part_on_part_picked = function(event, item) {
  if (!item || !item.unit)
    return;

  var $elt = $(this),
      id   = $elt.prop('id');

  if (id == 'quotations_and_orders_order_id')
    $elt.closest('td').data('unit', item.unit);

  else {
    var $tr  = $elt.closest('tr');
    var text = ns.time_based_units[item.unit] ? kivi.t8("time and effort based position") : kivi.t8("flat-rate position");

    $tr.find('[data-unit-column=1]').html(item.unit);
    $tr.find('[data-position-type-column=1]').html(text);
  }
};

// -------------------------------------------------------------------------
// ---------------------------- general actions ----------------------------
// -------------------------------------------------------------------------

ns.create_reqspec_pdf = function(key, opt) {
  var data = {
    action: "RequirementSpec/create_pdf",
    id:     $('#requirement_spec_id').val()
  };
  $.download("controller.pl", data);
};

ns.create_reqspec_html = function(key, opt) {
  window.open("controller.pl?action=RequirementSpec/create_html&id=" + encodeURIComponent($('#requirement_spec_id').val()), '_blank');
  return true;
};

ns.copy_reqspec = function(key, opt) {
  window.location.href = "controller.pl?action=RequirementSpec/new&copy_source_id=" + encodeURIComponent($('#requirement_spec_id').val());
  return true;
};

ns.delete_reqspec = function(key, opt) {
  if (confirm(kivi.t8("Are you sure?")))
    window.location.href = "controller.pl?action=RequirementSpec/destroy&id=" + encodeURIComponent($('#requirement_spec_id').val());
  return true;
};

ns.disable_commands = function(key, opt) {
  if (key === "create_version")
    return ($('#current_version_id').val() || '') == '' ? false : true;
  return false;
};

// -------------------------------------------------------------------------
// -------------------------------- versions -------------------------------
// -------------------------------------------------------------------------

ns.find_versioned_copy_id = function(clicked_elt) {
  var id = $(clicked_elt).find("[name=versioned_copy_id]");
  return id.size() ? id.val() : undefined;
};

ns.disable_versioned_copy_item_commands = function(key, opt) {
  if (key === "revert_to_version")
    return !ns.find_versioned_copy_id(opt.$trigger);
  return false;
};

ns.create_version = function() {
  kivi.popup_dialog({ url:    'controller.pl',
                      data:   { action:              'RequirementSpecVersion/new',
                                requirement_spec_id: $('#requirement_spec_id').val() },
                      dialog: { title: kivi.t8('Create a new version') }});
  return true;
};

ns.create_pdf_for_versioned_copy_ajax_call = function(key, opt) {
  var data = {
    action: "RequirementSpec/create_pdf",
    id:     ns.find_versioned_copy_id(opt.$trigger) || $('#requirement_spec_id').val()
  };
  $.download("controller.pl", data);

  return true;
};

ns.create_html_for_versioned_copy_ajax_call = function(key, opt) {
  window.open("controller.pl?action=RequirementSpec/create_html&id=" + encodeURIComponent(ns.find_versioned_copy_id(opt.$trigger) || $('#requirement_spec_id').val()), '_blank');
  return true;
};

ns.revert_to_versioned_copy_ajax_call = function(key, opt) {
  if (!confirm(kivi.t8('Do you really want to revert to this version?')))
    return true;

  var data = {
    action:            'RequirementSpec/revert_to',
    versioned_copy_id: ns.find_versioned_copy_id(opt.$trigger),
    id:                $('#requirement_spec_id').val()
  };

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

// -------------------------------------------------------------------------
// -------------------------- time/cost estimate ---------------------------
// -------------------------------------------------------------------------

ns.standard_time_cost_estimate_ajax_call = function(key, opt) {
  if (key == 'cancel') {
    if (confirm(kivi.t8('Do you really want to cancel?'))) {
      $('#time_cost_estimate').show();
      $('#time_cost_estimate_form_container').remove();
    }
    return true;
  }

  var add_data = '';
  if (key == 'save_keep_open') {
    key      = 'save';
    add_data = 'keep_open=1&';
  }

  var data = "action=RequirementSpec/ajax_" + key + "_time_and_cost_estimate&" + add_data;

  if (key == 'save')
    data += $('#edit_time_cost_estimate_form').serialize()
         +  '&' + $('#current_content_type').serialize()
         +  '&' + $('#current_content_id').serialize();
  else
    data += 'id=' + encodeURIComponent($('#requirement_spec_id').val());

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.time_cost_estimate_input_key_down = function(event) {
  if(event.keyCode == 13) {
    event.preventDefault();
    ns.standard_time_cost_estimate_ajax_call('save');
    return false;
  }
};

// -------------------------------------------------------------------------
// -------------------------- additional parts -----------------------------
// -------------------------------------------------------------------------

ns.standard_additional_parts_ajax_call = function(key, opt) {
  var add_data = '';
  if (key == 'save_keep_open') {
    key      = 'save';
    add_data = 'keep_open=1&';
  }

  var data = "action=RequirementSpecPart/ajax_" + key + "&" + add_data + 'requirement_spec_id=' + encodeURIComponent($('#requirement_spec_id').val()) + '&';

  if (key == 'save')
    data += $('#edit_additional_parts_form').serialize();

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.prepare_edit_additional_parts_form = function() {
  $("#edit_additional_parts_list tbody").sortable({
    distance: 5,
    handle:   '.dragdrop',
    helper:   function(event, ui) {
      ui.children().each(function() {
        $(this).width($(this).width());
      });
      return ui;
    }

  });
};

ns.cancel_edit_additional_parts_form = function() {
  if (confirm(kivi.t8('Do you really want to cancel?'))) {
    $('#additional_parts_list_container').show();
    $('#additional_parts_form_container').remove();
  }
  return true;
};

ns.additional_parts_input_key_down = function(event) {
  if(event.keyCode == 13) {
    event.preventDefault();
    ns.standard_additional_parts_ajax_call('save');
    return false;
  }
};

ns.add_additional_part = function() {
  var part_id = $('#additional_parts_add_part_id').val();
  if (!part_id || (part_id == ''))
    return false;

  var rspec_id = $('#requirement_spec_id').val();
  var data     = 'action=RequirementSpecPart/ajax_add&requirement_spec_id=' + encodeURIComponent(rspec_id) + '&part_id=' + encodeURIComponent(part_id);

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.delete_additional_part = function(key, opt) {
  opt.$trigger.remove();
  if (!$('#edit_additional_parts_list tbody tr').size()) {
   $('#edit_additional_parts_list_empty').show();
   $('#edit_additional_parts_list').hide();
  }

  return true;
};

// -------------------------------------------------------------------------
// ------------------------------- tab widget ------------------------------
// -------------------------------------------------------------------------
var content_div_ids_for_tab_headers = {
    'tab-header-function-block':     'function-blocks-tab'
  , 'tab-header-basic-settings':     'ui-tabs-1'
  , 'tab-header-time-cost-estimate': 'ui-tabs-2'
  , 'tab-header-additional-parts':   'ui-tabs-3'
  , 'tab-header-versions':           'ui-tabs-4'
  , 'tab-header-quotations-orders':  'ui-tabs-5'
};

ns.tabs_before_activate = function(event, ui) {
  if (!ui.oldTab)
    return true;

  var content_div_id = content_div_ids_for_tab_headers[ $(ui.oldTab).attr('id') ];
  if (!content_div_id || (content_div_id == 'function-blocks-tab'))
    return true;

  var inputs = $('#' + content_div_id).find('input,select,textarea').filter('[type!=hidden]');
  if (!inputs.size() || confirm(kivi.t8("If you switch to a different tab without saving you will lose the data you've entered in the current tab.")))
    return true;

  var new_focus = $(inputs).filter(':focusable')[0];
  if (new_focus)
    $(new_focus).focus();

  return false;
};

// -------------------------------------------------------------------------
// ----------------------------- context menus -----------------------------
// -------------------------------------------------------------------------

ns.create_context_menus = function(data) {
  var general_actions;
  if (data.is_template) {
    general_actions = {
        sep98:           "---------"
      , general_actions: { name: kivi.t8('Requirement spec template actions'), className: 'context-menu-heading' }
      // , sep99:           "---------"
      , copy_reqspec:    { name: kivi.t8('Copy template'),   icon: "copy",   callback: kivi.requirement_spec.copy_reqspec   }
      , delete_reqspec:  { name: kivi.t8('Delete template'), icon: "delete", callback: kivi.requirement_spec.delete_reqspec }
      , sep_paste_template: "---------"
      , renumber:        { name: kivi.t8('Renumber sections and function blocks'), icon: "renumber", callback: kivi.requirement_spec.renumber }
    };

    $.contextMenu({
      selector: '.basic-settings-context-menu',
      items:    $.extend({
          heading: { name: kivi.t8('Basic settings actions'), className: 'context-menu-heading' }
        , edit:    { name: kivi.t8('Edit'), icon: "edit", callback: kivi.requirement_spec.standard_basic_settings_ajax_call }
      }, general_actions)
    });

  } else {                      // if (is_template)
    general_actions = {
        sep98:              "---------"
      , general_actions:    { name: kivi.t8('Requirement spec actions'), className: 'context-menu-heading' }
      , create_pdf:         { name: kivi.t8('Create PDF'),              icon: "pdf",    callback: kivi.requirement_spec.create_reqspec_pdf }
      , create_html:        { name: kivi.t8('Create HTML'),             icon: "html",   callback: kivi.requirement_spec.create_reqspec_html }
      , create_version:     { name: kivi.t8('Create new version'),      icon: "new",    callback: kivi.requirement_spec.create_version, disabled: kivi.requirement_spec.disable_commands }
      , copy_reqspec:       { name: kivi.t8('Copy requirement spec'),   icon: "copy",   callback: kivi.requirement_spec.copy_reqspec   }
      , delete_reqspec:     { name: kivi.t8('Delete requirement spec'), icon: "delete", callback: kivi.requirement_spec.delete_reqspec }
      , sep_renumber:       "---------"
      , renumber:           { name: kivi.t8('Renumber sections and function blocks'), icon: "renumber", callback: kivi.requirement_spec.renumber }
      , sep_paste_template: "---------"
      , paste_template:     { name: kivi.t8('Paste template'),     icon: "paste",  callback: kivi.requirement_spec.paste_template }
    };

    var versioned_copy_actions = {
        heading:             { name: kivi.t8('Version actions'), className: 'context-menu-heading' }
      , create_version_pdf:  { name: kivi.t8('Create PDF'),        icon: "pdf",    callback: kivi.requirement_spec.create_pdf_for_versioned_copy_ajax_call                                                                      }
      , create_version_html: { name: kivi.t8('Create HTML'),       icon: "html",   callback: kivi.requirement_spec.create_html_for_versioned_copy_ajax_call                                                                     }
      , revert_to_version:   { name: kivi.t8('Revert to version'), icon: "revert", callback: kivi.requirement_spec.revert_to_versioned_copy_ajax_call,     disabled: kivi.requirement_spec.disable_versioned_copy_item_commands }
    };

    if (!data.html_template_exists) {
      delete general_actions.create_html;
      delete versioned_copy_actions.create_version_html;
    }

    $.contextMenu({
      selector: '.versioned-copy-context-menu',
      items:    $.extend(versioned_copy_actions, general_actions)
    });

    $.contextMenu({
      selector: ':has(> .basic-settings-context-menu:visible)',
      items:    $.extend({
          heading:           { name: kivi.t8('Basic settings actions'), className: 'context-menu-heading' }
        , edit:              { name: kivi.t8('Edit'),              icon: "edit", callback: kivi.requirement_spec.standard_basic_settings_ajax_call }
        , edit_project_link: { name: kivi.t8('Edit project link'),               callback: kivi.requirement_spec.standard_basic_settings_ajax_call }
      }, general_actions)
    });

    $.contextMenu({
      selector: ':has(> .edit-project-link-context-menu:visible)',
      items:    $.extend({
          heading: { name: kivi.t8('Project link actions'), className: 'context-menu-heading' }
        , save:    { name: kivi.t8('Save'),   icon: "save",  callback: kivi.requirement_spec.standard_basic_settings_ajax_call }
        , cancel:  { name: kivi.t8('Cancel'), icon: "close", callback: kivi.requirement_spec.standard_basic_settings_ajax_call }
      }, general_actions)
    });

    var paste_template_actions = {
    };
  }                             // if (is_template) ... else ...

  $.contextMenu({
    selector: '.text-block-context-menu',
    events:   {
        show: kivi.requirement_spec.text_block_popup_menu_shown
      , hide: kivi.requirement_spec.text_block_popup_menu_hidden
    },
    items:    $.extend({
        heading: { name: kivi.t8('Text block actions'),    className: 'context-menu-heading' }
      , add:     { name: kivi.t8('Add text block'),        icon: "add",    callback: kivi.requirement_spec.standard_text_block_ajax_call }
      , edit:    { name: kivi.t8('Edit text block'),       icon: "edit",   callback: kivi.requirement_spec.standard_text_block_ajax_call, disabled: kivi.requirement_spec.disable_edit_text_block_commands }
      , delete:  { name: kivi.t8('Delete text block'),     icon: "delete", callback: kivi.requirement_spec.ask_delete_text_block,         disabled: kivi.requirement_spec.disable_edit_text_block_commands }
      , add_picture: { name: kivi.t8('Add picture to text block'), icon: "add-picture", callback: kivi.requirement_spec.add_edit_text_block_picture_ajax_call, disabled: kivi.requirement_spec.disable_edit_text_block_commands }
      , sep1:    "---------"
      , flag:    { name: kivi.t8('Toggle marker'),         icon: "flag",   callback: kivi.requirement_spec.standard_text_block_ajax_call, disabled: kivi.requirement_spec.disable_edit_text_block_commands }
      , sep2:    "---------"
      , copy:    { name: kivi.t8('Copy'),                  icon: "copy",   callback: kivi.requirement_spec.standard_text_block_ajax_call, disabled: kivi.requirement_spec.disable_edit_text_block_commands }
      , paste:   { name: kivi.t8('Paste'),                 icon: "paste",  callback: kivi.requirement_spec.standard_text_block_ajax_call  }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.text-block-picture-context-menu',
    events:   {
        show: kivi.requirement_spec.text_block_picture_popup_menu_shown
      , hide: kivi.requirement_spec.text_block_picture_popup_menu_hidden
    },
    items:    $.extend({
        heading:          { name: kivi.t8('Text block picture actions'), className: 'context-menu-heading'                                                 }
      , add_picture:      { name: kivi.t8('Add picture'),      icon: "add-picture", callback: kivi.requirement_spec.add_edit_text_block_picture_ajax_call  }
      , edit_picture:     { name: kivi.t8('Edit picture'),     icon: "edit",        callback: kivi.requirement_spec.add_edit_text_block_picture_ajax_call  }
      , delete_picture:   { name: kivi.t8('Delete picture'),   icon: "delete",      callback: kivi.requirement_spec.ask_delete_text_block_picture          }
      , download_picture: { name: kivi.t8('Download picture'), icon: "download",    callback: kivi.requirement_spec.standard_text_block_picture_ajax_call  }
      , sep2:             "---------"
      , copy_picture:     { name: kivi.t8('Copy'),             icon: "copy",        callback: kivi.requirement_spec.standard_text_block_picture_ajax_call  }
      , paste_picture:    { name: kivi.t8('Paste'),            icon: "paste",       callback: kivi.requirement_spec.standard_text_block_picture_ajax_call  }
    }, general_actions)
  });

  $.contextMenu({
    selector: ':has(> .edit-basic-settings-context-menu:visible)',
    items:    $.extend({
        heading: { name: kivi.t8('Basic settings actions'), className: 'context-menu-heading' }
      , save:    { name: kivi.t8('Save'),   icon: "save",  callback: kivi.requirement_spec.standard_basic_settings_ajax_call }
      , cancel:  { name: kivi.t8('Cancel'), icon: "close", callback: kivi.requirement_spec.standard_basic_settings_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: ':has(> div > .time-cost-estimate-context-menu:visible)',
    items:    $.extend({
        heading: { name: kivi.t8('Time/cost estimate actions'), className: 'context-menu-heading' }
      , edit:    { name: kivi.t8('Edit'), icon: "edit", callback: kivi.requirement_spec.standard_time_cost_estimate_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: ':has(> .edit-time-cost-estimate-context-menu:visible)',
    items:    $.extend({
        heading: { name: kivi.t8('Time/cost estimate actions'), className: 'context-menu-heading' }
      , save:    { name: kivi.t8('Save'),   icon: "save",  callback: kivi.requirement_spec.standard_time_cost_estimate_ajax_call }
      , save_keep_open: { name: kivi.t8('Save and keep open'), icon: "save", callback: kivi.requirement_spec.standard_time_cost_estimate_ajax_call }
      , cancel:  { name: kivi.t8('Cancel'), icon: "close", callback: kivi.requirement_spec.standard_time_cost_estimate_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: ':has(> .additional-parts-context-menu:visible)',
    items:    $.extend({
        heading: { name: kivi.t8('Additional articles actions'), className: 'context-menu-heading' }
      , edit:    { name: kivi.t8('Edit'), icon: "edit", callback: kivi.requirement_spec.standard_additional_parts_ajax_call }
    }, general_actions)
  });

  var additional_parts_actions = {
      save:           { name: kivi.t8('Save'),               icon: "save",  callback: kivi.requirement_spec.standard_additional_parts_ajax_call }
    , save_keep_open: { name: kivi.t8('Save and keep open'), icon: "save",  callback: kivi.requirement_spec.standard_additional_parts_ajax_call }
    , cancel:         { name: kivi.t8('Cancel'),             icon: "close",  callback: kivi.requirement_spec.cancel_edit_additional_parts_form }
  };

  $.contextMenu({
    selector: ':has(> .edit-additional-parts-context-menu:visible)',
    items:    $.extend({
        heading:        { name: kivi.t8('Additional articles actions'), className: 'context-menu-heading' }
    }, additional_parts_actions, general_actions)
  });

  $.contextMenu({
    selector: '.edit-additional-parts-row-context-menu',
    items:    $.extend({
        heading:        { name: kivi.t8('Additional articles actions'), className: 'context-menu-heading' }
      , delete:         { name: kivi.t8('Remove article'),     icon: "delete", callback: kivi.requirement_spec.delete_additional_part }
    }, additional_parts_actions, general_actions)
  });

  $.contextMenu({
    selector: ':has(> .quotations-and-orders-context-menu:visible),.quotations-and-orders-order-context-menu',
    items:    $.extend({
        heading:            { name: kivi.t8('Quotations/Orders actions'), className: 'context-menu-heading'                                                                                            }
      , edit_assignment:    { name: kivi.t8('Edit article/section assignments'), icon: "edit",   callback: ns.standard_quotation_order_ajax_call                                                       }
      , sep1:               "---------"
      , new:                { name: kivi.t8('Create new qutoation/order'),       icon: "add",    callback: ns.standard_quotation_order_ajax_call, disabled: ns.disable_create_quotation_order_commands }
      , update:             { name: kivi.t8('Update quotation/order'),           icon: "update", callback: ns.standard_quotation_order_ajax_call, disabled: ns.disable_edit_quotation_order_commands   }
      , sep2:               "---------"
      , delete:             { name: kivi.t8('Delete quotation/order'),           icon: "delete", callback: ns.ask_delete_quotation_order,         disabled: ns.disable_edit_quotation_order_commands   }
    }, general_actions)
  });

  $.contextMenu({
    selector: ':has(> .quotations-and-orders-edit-assignment-context-menu:visible)',
    items:    $.extend({
        heading:         { name: kivi.t8('Edit article/section assignments'), className: 'context-menu-heading'    }
      , save_assignment: { name: kivi.t8('Save'),   icon: "edit",  callback: ns.standard_quotation_order_ajax_call }
      , cancel:          { name: kivi.t8('Cancel'), icon: "close", callback: ns.standard_quotation_order_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: ':has(> .quotations-and-orders-new-context-menu:visible)',
    items:    $.extend({
        heading: { name: kivi.t8('Create new quotation/order'), className: 'context-menu-heading'          }
      , create:  { name: kivi.t8('Create'), icon: "edit",  callback: ns.standard_quotation_order_ajax_call }
      , cancel:  { name: kivi.t8('Cancel'), icon: "close", callback: ns.standard_quotation_order_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: ':has(> .quotations-and-orders-update-context-menu:visible)',
    items:    $.extend({
        heading:   { name: kivi.t8('Update quotation/order'), className: 'context-menu-heading'               }
      , do_update: { name: kivi.t8('Update'), icon: "update", callback: ns.standard_quotation_order_ajax_call }
      , cancel:    { name: kivi.t8('Cancel'), icon: "close",  callback: ns.standard_quotation_order_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '#content',
    items:    general_actions
  });

  var events = {
      show: kivi.requirement_spec.item_popup_menu_shown
    , hide: kivi.requirement_spec.item_popup_menu_hidden
  };

  $.contextMenu({
    selector: '.section-context-menu',
    events:   events,
    items:    $.extend({
        heading:            { name: kivi.t8('Section/Function block actions'), className: 'context-menu-heading' }
      , add_section:        { name: kivi.t8('Add section'),        icon: "add",    callback: kivi.requirement_spec.standard_item_ajax_call }
      , add_function_block: { name: kivi.t8('Add function block'), icon: "add",    callback: kivi.requirement_spec.standard_item_ajax_call, disabled: kivi.requirement_spec.disable_add_function_block_command }
      , sep1:               "---------"
      , edit:               { name: kivi.t8('Edit'),               icon: "edit",   callback: kivi.requirement_spec.standard_item_ajax_call, disabled: kivi.requirement_spec.disable_edit_item_commands }
      , delete:             { name: kivi.t8('Delete'),             icon: "delete", callback: kivi.requirement_spec.ask_delete_item,         disabled: kivi.requirement_spec.disable_edit_item_commands }
      , sep2:               "---------"
      , flag:               { name: kivi.t8('Toggle marker'),      icon: "flag",   callback: kivi.requirement_spec.standard_item_ajax_call, disabled: kivi.requirement_spec.disable_edit_item_commands }
      , sep3:               "---------"
      , copy:               { name: kivi.t8('Copy'),               icon: "copy",   callback: kivi.requirement_spec.standard_item_ajax_call, disabled: kivi.requirement_spec.disable_edit_item_commands }
      , paste:              { name: kivi.t8('Paste'),              icon: "paste",  callback: kivi.requirement_spec.standard_item_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.function-block-context-menu,.sub-function-block-context-menu',
    events:   events,
    items:    $.extend({
        heading:                { name: kivi.t8('Function block actions'), className: 'context-menu-heading' }
      , add_function_block:     { name: kivi.t8('Add function block'),     icon: "add",    callback: kivi.requirement_spec.standard_item_ajax_call }
      , add_sub_function_block: { name: kivi.t8('Add sub function block'), icon: "add",    callback: kivi.requirement_spec.standard_item_ajax_call }
      , sep1:                   "---------"
      , edit:                   { name: kivi.t8('Edit'),                   icon: "edit",   callback: kivi.requirement_spec.standard_item_ajax_call, disabled: kivi.requirement_spec.disable_edit_item_commands }
      , delete:                 { name: kivi.t8('Delete'),                 icon: "delete", callback: kivi.requirement_spec.ask_delete_item,         disabled: kivi.requirement_spec.disable_edit_item_commands }
      , sep2:                   "---------"
      , flag:                   { name: kivi.t8('Toggle marker'),          icon: "flag",   callback: kivi.requirement_spec.standard_item_ajax_call, disabled: kivi.requirement_spec.disable_edit_item_commands }
      , sep3:                   "---------"
      , copy:                   { name: kivi.t8('Copy'),                   icon: "copy",   callback: kivi.requirement_spec.standard_item_ajax_call, disabled: kivi.requirement_spec.disable_edit_item_commands }
      , paste:                  { name: kivi.t8('Paste'),                  icon: "paste",  callback: kivi.requirement_spec.standard_item_ajax_call }
    }, general_actions)
  });
};

});                             // end of namespace(...., function() {...

function local_reinit_widgets() {
  kivi.run_once_for('#quotations_and_orders_order_id,[name="sections[].order_part_id"]', "assign_order_part_on_part_picked", function(elt) {
    $(elt).on('set_item:PartPicker', kivi.requirement_spec.assign_order_part_on_part_picked);
  });
}
