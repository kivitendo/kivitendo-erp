namespace('kivi.Clearing', function(ns) {
  'use strict';

  // The table of bookings is rendered by the server (clearing/_list.html).
  // Each row carries the raw values needed here as data attributes. This
  // module only shows/hides rows, keeps track of the selection and sums up
  // amounts; clearing and undoing is done by the controller.

  var anchor;            // row selected last, used by the matching filters
  var sort_state = {};

  // amounts are summed up in cents to avoid floating point errors
  var cents = function(amount) {
    return Math.round(Number(amount) * 100);
  };

  var format_cents = function(value) {
    return kivi.format_amount(value / 100, 2);
  };

  var days_between = function(date_a, date_b) {
    return Math.abs(Date.parse(date_a) - Date.parse(date_b)) / 86400000;
  };

  var iso_date = function(date) {
    if (!date) return undefined;
    return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0');
  };

  var option = function(name) {
    return $('#clearing_' + name).prop('checked');
  };

  var option_number = function(name, fallback) {
    var value = kivi.parse_amount($('#clearing_' + name).val());
    return (value === undefined || value === null || isNaN(value)) ? fallback : Math.abs(value);
  };

  var contains = function(haystack, needle) {
    return String(haystack || '').toLowerCase().indexOf(needle.toLowerCase()) !== -1;
  };

  var rows = function() {
    return $('#clearing_bookings tbody tr.listrow');
  };

  var selected_rows = function() {
    return rows().filter(function() { return $(this).find('.clearing_select').prop('checked'); });
  };

  var row_data = function($row) {
    return {
      id:         $row.data('id'),
      amount:     cents($row.data('amount')),
      transdate:  String($row.data('transdate')),
      reference:  String($row.data('reference')),
      contra:     String($row.data('contra')),
      employee:   String($row.data('employee')),
      project:    String($row.data('project')),
      project_id: String($row.data('project-id')),
      group_id:   $row.data('group-id')
    };
  };

  var sum_up = function($rows) {
    var sums = { count: $rows.length, debit: 0, credit: 0, balance: 0 };
    $rows.each(function() {
      var amount = cents($(this).data('amount'));
      if (amount < 0) sums.debit  -= amount;
      else            sums.credit += amount;
      sums.balance += amount;
    });
    return sums;
  };

  var amount_matches = function(amount, wanted) {
    amount = Math.abs(amount);
    wanted = Math.abs(wanted);
    if (!option('fuzzy_amount'))
      return amount === wanted;
    var tolerance = option_number('fuzzy_amount_percent', 0) / 100;
    return amount >= wanted * (1 - tolerance) && amount <= wanted * (1 + tolerance);
  };

  var date_matches = function(date, wanted) {
    var days = option('fuzzy_date') ? option_number('fuzzy_date_days', 0) : 0;
    return days_between(date, wanted) <= days;
  };

  // filters typed into the second header row
  var column_filters = function() {
    return {
      transdate: iso_date(kivi.parse_date($('#clearing_search_transdate').val() || '')),
      reference: $('#clearing_search_reference').val() || '',
      amount:    kivi.parse_amount($('#clearing_search_amount').val() || ''),
      contra:    $('#clearing_search_contra').val() || '',
      employee:  $('#clearing_search_employee').val() || '',
      project:   $('#clearing_search_project').val() || ''
    };
  };

  var passes_column_filters = function(data, filters) {
    if (filters.transdate && !date_matches(data.transdate, filters.transdate))       return false;
    if (filters.reference && !contains(data.reference, filters.reference))           return false;
    if (filters.amount    && !amount_matches(data.amount, cents(filters.amount)))    return false;
    if (filters.contra    && !contains(data.contra, filters.contra))                 return false;
    if (filters.employee  && !contains(data.employee, filters.employee))             return false;
    if (filters.project   && !contains(data.project, filters.project))               return false;
    return true;
  };

  // "only show bookings matching the selection" options
  var passes_matching_filters = function(data, reference_data, selected_sums) {
    if (!reference_data) return true;

    // contra amount: the booking has to balance the current selection
    if (option('match_amount')) {
      if (data.group_id)                                                  return false;
      if (selected_sums.balance === 0)                                    return false;
      if (Math.sign(data.amount) === Math.sign(selected_sums.balance))    return false;
      if (!amount_matches(data.amount, selected_sums.balance))            return false;
    }
    if (option('match_date')      && !date_matches(data.transdate, reference_data.transdate)) return false;
    if (option('match_reference') && data.reference  !== reference_data.reference)          return false;
    if (option('match_project')   && data.project_id !== reference_data.project_id)         return false;
    if (option('match_employee')  && data.employee   !== reference_data.employee)           return false;
    return true;
  };

  ns.apply_filters = function() {
    var filters        = column_filters();
    var $selected      = selected_rows();
    var selected_sums  = sum_up($selected);
    var reference_data = ($selected.length && anchor && anchor.find('.clearing_select').prop('checked')) ? row_data(anchor) : undefined;

    rows().each(function() {
      var $row    = $(this);
      var data    = row_data($row);
      var visible = $row.find('.clearing_select').prop('checked')   // selected bookings are always shown
                 || (passes_column_filters(data, filters) && passes_matching_filters(data, reference_data, selected_sums));
      $row.toggle(!!visible);
    });

    ns.update_sums();
  };

  ns.update_sums = function() {
    var visible  = sum_up(rows().filter(':visible'));
    var selected = sum_up(selected_rows());

    $('#clearing_visible_count').text(visible.count);
    $('#clearing_visible_debit').text(format_cents(visible.debit));
    $('#clearing_visible_credit').text(format_cents(visible.credit));
    $('#clearing_visible_balance').text(format_cents(visible.balance));

    $('#clearing_selected_count').text(selected.count);
    $('#clearing_selected_debit').text(format_cents(selected.debit));
    $('#clearing_selected_credit').text(format_cents(selected.credit));
    $('#clearing_selected_balance').text(format_cents(selected.balance));

    var $button = $('#clearing_create_button');
    if ($button.length) {
      var action = kivi.ActionBar.Action($button);
      if (selected.count >= 2 && selected.balance === 0) action.enable();
      else action.disable(kivi.t8('Select at least two bookings whose amounts add up to 0.'));
    }

    return selected;
  };

  ns.selection_changed = function($row) {
    if ($row && $row.find('.clearing_select').prop('checked'))
      anchor = $row;
    else if (!selected_rows().length)
      anchor = undefined;

    ns.apply_filters();

    var selected = sum_up(selected_rows());
    if (option('automatic') && selected.count >= 2 && selected.balance === 0)
      ns.create_cleared_group();
  };

  ns.toggle_row = function($row) {
    var $checkbox = $row.find('.clearing_select');
    if ($checkbox.prop('disabled')) return;
    $checkbox.prop('checked', !$checkbox.prop('checked'));
    $row.toggleClass('clearing_selected', $checkbox.prop('checked'));
    ns.selection_changed($row);
  };

  // Selecting all shown bookings never clears them automatically, even if
  // "automatic clearing" is active: the user has to confirm with the button.
  ns.select_all_visible = function() {
    rows().filter(':visible').each(function() {
      var $checkbox = $(this).find('.clearing_select');
      if (!$checkbox.prop('disabled')) {
        $checkbox.prop('checked', true);
        $(this).addClass('clearing_selected');
      }
    });
    ns.apply_filters();
  };

  ns.deselect_all = function() {
    rows().find('.clearing_select').prop('checked', false);
    rows().removeClass('clearing_selected');
    $('#clearing_select_all_visible').prop('checked', false);
    anchor = undefined;
    ns.apply_filters();
  };

  ns.reset_column_filters = function() {
    $('.clearing_column_filter').val('');
    ns.apply_filters();
  };

  ns.sort_by = function(key) {
    var direction   = sort_state.key === key ? -sort_state.direction : 1;
    sort_state      = { key: key, direction: direction };
    var $tbody      = $('#clearing_bookings tbody');
    var numeric     = key === 'amount' || key === 'group_id';

    var sorted = rows().get().sort(function(a, b) {
      var va = $(a).data(key.replace('_', '-')), vb = $(b).data(key.replace('_', '-'));
      if (key === 'amount') { va = Math.abs(va); vb = Math.abs(vb); }
      if (numeric)          { va = Number(va) || 0; vb = Number(vb) || 0; }
      else                  { va = String(va).toLowerCase(); vb = String(vb).toLowerCase(); }
      return va < vb ? -direction : va > vb ? direction : 0;
    });
    $tbody.append(sorted);
  };

  //
  // server calls
  //

  ns.load_list = function() {
    if (!$('#filter_chart_id').val()) {
      $('#clearing_list').html('');
      kivi.Flash.display_flash('error', kivi.t8('No chart selected'));
      $('#filter_chart_id_name').focus();
      return;
    }

    var data = $('#clearing_filter').serializeArray();
    data.push({ name: 'action', value: 'Clearing/list' });
    $.post('controller.pl', data, kivi.eval_json_result);
  };

  var creating = false;
  ns.create_cleared_group = function() {
    var $selected = selected_rows();
    var sums      = sum_up($selected);
    if (creating || sums.count < 2 || sums.balance !== 0) return;

    creating = true;
    var data = [ { name: 'action', value: 'Clearing/create_cleared_group' } ];
    $selected.each(function() { data.push({ name: 'acc_trans_ids[]', value: $(this).data('id') }); });

    $.post('controller.pl', data, kivi.eval_json_result)
      .always(function() { creating = false; });
  };

  ns.show_cleared_group = function(cleared_group_id) {
    kivi.popup_dialog({
      url:    'controller.pl',
      data:   { action: 'Clearing/show_cleared_group', cleared_group_id: cleared_group_id },
      id:     'clearing_group_dialog',
      dialog: { title: kivi.t8('Cleared group'), width: 900, height: 500 }
    });
  };

  ns.remove_cleared_group = function(cleared_group_id) {
    if (!confirm(kivi.t8('Do you really want to undo this clearing?'))) return;

    $.post('controller.pl', { action: 'Clearing/remove_cleared_group', cleared_group_id: cleared_group_id }, kivi.eval_json_result);
  };

  // called by the controller after the bookings have been cleared
  ns.mark_cleared = function(cleared_group_id, acc_trans_ids) {
    var ids       = acc_trans_ids.map(String);
    var keep_rows = $('#filter_load_cleared').prop('checked');

    rows().each(function() {
      var $row = $(this);
      if (ids.indexOf(String($row.data('id'))) === -1) return;

      if (!keep_rows) {
        $row.remove();
        return;
      }
      $row.data('group-id', cleared_group_id).attr('data-group-id', cleared_group_id);
      $row.removeClass('clearing_selected').addClass('clearing_cleared');
      $row.find('.clearing_select').prop('checked', false).prop('disabled', true);
      $row.find('.clearing_group_cell').html('<a href="#" class="clearing_show_group">&#10003;</a>');
    });

    anchor = undefined;
    ns.apply_filters();
  };

  // called by the controller after a clearing has been undone
  ns.mark_uncleared = function(cleared_group_id) {
    rows().each(function() {
      var $row = $(this);
      if (String($row.data('group-id')) !== String(cleared_group_id)) return;

      $row.data('group-id', '').attr('data-group-id', '');
      $row.removeClass('clearing_cleared');
      $row.find('.clearing_select').prop('disabled', false);
      $row.find('.clearing_group_cell').html('');
    });

    ns.apply_filters();
  };

  // called by the controller after the list has been rendered
  ns.init_list = function() {
    anchor     = undefined;
    sort_state = {};
    kivi.reinit_widgets();
    ns.apply_filters();
  };

  ns.init = function() {
    var $list = $('#clearing_list');

    $('#filter_chart_id').on('set_item:ChartPicker', ns.load_list);

    $list.on('change', '.clearing_select', function() {
      var $row = $(this).closest('tr');
      $row.toggleClass('clearing_selected', $(this).prop('checked'));
      ns.selection_changed($row);
    });

    // clicking anywhere on a row (except links and inputs) toggles it
    $list.on('click', '#clearing_bookings tbody tr.listrow td', function(event) {
      if ($(event.target).is('a, input')) return;
      ns.toggle_row($(this).closest('tr'));
    });

    $list.on('click', '.clearing_show_group', function(event) {
      event.preventDefault();
      ns.show_cleared_group($(this).closest('tr').data('group-id'));
    });

    $list.on('change', '#clearing_select_all_visible', function() {
      if ($(this).prop('checked')) ns.select_all_visible();
      else                         ns.deselect_all();
    });

    $list.on('click', '.clearing_sortable', function() {
      ns.sort_by($(this).data('sort-key'));
    });

    $list.on('keyup change', '.clearing_column_filter', function() {
      clearTimeout(ns.filter_timeout);
      ns.filter_timeout = setTimeout(ns.apply_filters, 300);
    });

    $('.clearing_option').on('change keyup', function() {
      ns.apply_filters();
    });

    // Enter clears the selection if it is balanced, Escape resets it.
    // Not while typing in an input field.
    $(document).on('keyup', function(event) {
      if ($(event.target).is('input, select, textarea')) return;
      if (event.key === 'Enter')  ns.create_cleared_group();
      if (event.key === 'Escape') ns.deselect_all();
    });
  };
});

$(kivi.Clearing.init);
