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

// -------------------------------------------------------------------------
// ------------------------------ text blocks ------------------------------
// -------------------------------------------------------------------------

ns.find_text_block_id = function(clicked_elt) {
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
};

ns.find_text_block_output_position = function(clicked_elt) {
  var output_position = $(clicked_elt).closest('#text-block-list-container').find('#text_block_output_position').val();
  if (output_position)
    return output_position;

  var type = $(clicked_elt).closest('#tb-back,#tb-front').data('type');
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
  if (ns.find_item_id(opt.$trigger))
    return false;
  return opt.$trigger.attr('id') != "section-list-empty";
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

// -------------------------------------------------------------------------
// ------------------------------- templates -------------------------------
// -------------------------------------------------------------------------

ns.paste_template = function(key, opt, other_data) {
  open_jqm_window({ url: 'controller.pl?action=RequirementSpec/select_template_to_paste' });
};

ns.paste_selected_template = function(template_id) {
  $('#jqm_popup_dialog').jqmClose();

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
// -------------------------- time/cost estimate ---------------------------
// -------------------------------------------------------------------------

ns.standard_time_cost_estimate_ajax_call = function(key, opt) {
  if ((key == 'cancel') && !confirm(kivi.t8('Do you really want to cancel?')))
    return true;

  var data = "action=RequirementSpec/ajax_" + key + "_time_and_cost_estimate&";

  if (key == 'save')
    data += $('#edit_time_cost_estimate_form').serialize()
         +  '&' + $('#current_content_type').serialize()
         +  '&' + $('#current_content_id').serialize();
  else
    data += 'id=' + encodeURIComponent($('#requirement_spec_id').val());

  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

// -------------------------------------------------------------------------
// --------------------------- quotations/orders ---------------------------
// -------------------------------------------------------------------------

ns.find_quotation_order_id = function(clicked_elt) {
  return $(clicked_elt).find('>[name=order_id]').val();
};

ns.standard_quotation_order_ajax_call = function(key, opt) {
  if ((key == 'cancel') && !confirm(kivi.t8('Do you really want to cancel?')))
    return true;

  var data = 'action=RequirementSpecOrder/' + key
           + '&' + $('#requirement_spec_id').serialize();

  if ((key == 'save_assignment') || (key == 'create'))
    data += '&' + $('#quotations_and_orders_article_assignment_form').serialize();
  else
    data += '&id=' + encodeURIComponent(ns.find_quotation_order_id(opt.$trigger));

  // console.log("I would normally POST the following now:");
  // console.log(data);
  $.post("controller.pl", data, kivi.eval_json_result);

  return true;
};

ns.disable_edit_quotation_order_commands = function(key, opt) {
  return ns.find_quotation_order_id(opt.$trigger) == undefined;
};

ns.disable_create_quotation_order_commands = function(key, opt) {
  return !$('#quotations_and_orders_sections');
};

ns.assign_order_part_id_to_all = function() {
  var order_part_id = $('#quoations_and_orders_order_id').val();
  $('#quotations_and_orders_article_assignment_form SELECT[name="sections[].order_part_id"]').each(function(idx, elt) {
    $(elt).val(order_part_id);
  });
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
  return id ? id.val() : undefined;
};

ns.disable_versioned_copy_item_commands = function(key, opt) {
  if (key === "revert_to_version")
    return !ns.find_versioned_copy_id(opt.$trigger);
  return false;
};

ns.create_version = function() {
  open_jqm_window({ url:  'controller.pl',
                    data: { action:              'RequirementSpecVersion/new',
                            requirement_spec_id: $('#requirement_spec_id').val() },
                    id:   'new_requirement_spec_version_window' });
  return true;
};

ns.create_pdf_for_versioned_copy_ajax_call = function(key, opt) {
  var data = {
    action: "RequirementSpec/create_pdf",
    id:     ns.find_versioned_copy_id(opt.$trigger)
  };
  $.download("controller.pl", data);

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
// ----------------------------- context menus -----------------------------
// -------------------------------------------------------------------------

ns.create_context_menus = function(is_template) {
  if (is_template) {
    var general_actions = {
        sep98:           "---------"
      , general_actions: { name: kivi.t8('Requirement spec template actions'), className: 'context-menu-heading' }
      // , sep99:           "---------"
      , copy_reqspec:    { name: kivi.t8('Copy template'),   icon: "copy",   callback: kivi.requirement_spec.copy_reqspec   }
      , delete_reqspec:  { name: kivi.t8('Delete template'), icon: "delete", callback: kivi.requirement_spec.delete_reqspec }
    };

  } else {                      // if (is_template)
    var general_actions = {
        sep98:              "---------"
      , general_actions:    { name: kivi.t8('Requirement spec actions'), className: 'context-menu-heading' }
      , create_pdf:         { name: kivi.t8('Create PDF'),              icon: "pdf",    callback: kivi.requirement_spec.create_reqspec_pdf }
      , create_version:     { name: kivi.t8('Create new version'),      icon: "new",    callback: kivi.requirement_spec.create_version, disabled: kivi.requirement_spec.disable_commands }
      , copy_reqspec:       { name: kivi.t8('Copy requirement spec'),   icon: "copy",   callback: kivi.requirement_spec.copy_reqspec   }
      , delete_reqspec:     { name: kivi.t8('Delete requirement spec'), icon: "delete", callback: kivi.requirement_spec.delete_reqspec }
      , sep_paste_template: "---------"
      , paste_template:     { name: kivi.t8('Paste template'),     icon: "paste",  callback: kivi.requirement_spec.paste_template }
    };

    $.contextMenu({
      selector: '.versioned-copy-context-menu',
      items:    $.extend({
          heading:            { name: kivi.t8('Version actions'), className: 'context-menu-heading' }
        , create_version_pdf: { name: kivi.t8('Create PDF'),        icon: "pdf",    callback: kivi.requirement_spec.create_pdf_for_versioned_copy_ajax_call                                                                      }
        , revert_to_version:  { name: kivi.t8('Revert to version'), icon: "revert", callback: kivi.requirement_spec.revert_to_versioned_copy_ajax_call,     disabled: kivi.requirement_spec.disable_versioned_copy_item_commands }
      }, general_actions)
    });

    var paste_template_actions = {
    };
  }                             // if (is_template) ... else ...

  var events = {
      show: kivi.requirement_spec.text_block_popup_menu_shown
    , hide: kivi.requirement_spec.text_block_popup_menu_hidden
  };

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
      , sep1:    "---------"
      , flag:    { name: kivi.t8('Toggle marker'),         icon: "flag",   callback: kivi.requirement_spec.standard_text_block_ajax_call, disabled: kivi.requirement_spec.disable_edit_text_block_commands }
      , sep2:    "---------"
      , copy:    { name: kivi.t8('Copy'),                  icon: "copy",   callback: kivi.requirement_spec.standard_text_block_ajax_call, disabled: kivi.requirement_spec.disable_edit_text_block_commands }
      , paste:   { name: kivi.t8('Paste'),                 icon: "paste",  callback: kivi.requirement_spec.standard_text_block_ajax_call  }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.time-cost-estimate-context-menu',
    items:    $.extend({
        heading: { name: kivi.t8('Time/cost estimate actions'), className: 'context-menu-heading' }
      , edit:    { name: kivi.t8('Edit'), icon: "edit", callback: kivi.requirement_spec.standard_time_cost_estimate_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.edit-time-cost-estimate-context-menu',
    items:    $.extend({
        heading: { name: kivi.t8('Time/cost estimate actions'), className: 'context-menu-heading' }
      , save:    { name: kivi.t8('Save'),   icon: "save",  callback: kivi.requirement_spec.standard_time_cost_estimate_ajax_call }
      , cancel:  { name: kivi.t8('Cancel'), icon: "close", callback: kivi.requirement_spec.standard_time_cost_estimate_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.quotations-and-orders-context-menu,.quotations-and-orders-order-context-menu',
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
    selector: '.quotations-and-orders-edit-assignment-context-menu',
    items:    $.extend({
        heading:         { name: kivi.t8('Edit article/section assignments'), className: 'context-menu-heading'    }
      , save_assignment: { name: kivi.t8('Save'),   icon: "edit",  callback: ns.standard_quotation_order_ajax_call }
      , cancel:          { name: kivi.t8('Cancel'), icon: "close", callback: ns.standard_quotation_order_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '.quotations-and-orders-new-context-menu',
    items:    $.extend({
        heading: { name: kivi.t8('Create new quotation/order'), className: 'context-menu-heading'    }
      , create:  { name: kivi.t8('Create'), icon: "edit",  callback: ns.standard_quotation_order_ajax_call }
      , cancel:  { name: kivi.t8('Cancel'), icon: "close", callback: ns.standard_quotation_order_ajax_call }
    }, general_actions)
  });

  $.contextMenu({
    selector: '#content',
    items:    general_actions
  });

  events = {
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
