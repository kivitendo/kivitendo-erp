namespace('kivi.DatePeriodAdder', function(ns) {

  ns.add = function(prefix) {
    const counterEl = $(`#${prefix}_counter`);
    if (!counterEl) {
      console.error('DatePeriodAdder: counter element not found for prefix', prefix);
      return;
    }
    let count = parseInt(counterEl.val()) || 1;
    count += 1;
    counterEl.val(count);

    const name = `${prefix}_${count}`;
    const url  = 'controller.pl?action=DatePeriodAdder/ajax_get';

    $.ajax({
      url: url,
      type: 'POST',
      data: { name: name },
      success: function(result) {
        try {
          if (result && result.html) {
            $(`#${prefix}_container`).append(result.html);

            // get the date period element we just added
            const container = $(`#${name}`);

            // add a link to remove the date period
            const removeLink = $(`<a href="#" onclick="kivi.DatePeriodAdder.remove('${prefix}', '${name}'); return false;">✘</a>`);
            container.append(removeLink);

            // attach jquery-ui date picker to the date input elements use .datepicker()
            $(`#${name}_from_date`).datepicker();
            $(`#${name}_to_date`).datepicker();

            // add a hidden input field with the name "${prefix}_names[]" and value equal to the generated name
            // this is used to retrieve the name of the input elements when processing the date elements
            // on the server (after form submission)
            // TODO: consider moving this to the server side
            const hiddenInput = $('<input>')
              .attr('type', 'hidden')
              .attr('name', `${prefix}_names[]`)
              .attr('value', name);
            $(`#${prefix}_container`).append(hiddenInput);
          }
        } catch (e) {
          console.error('DatePeriodAdder: failed to append result', e, result);
        }
      },
      error: function(xhr, status, err) {
        console.error('DatePeriodAdder: ajax error', status, err);
      }
    });
  };

  ns.remove = function(prefix, name) {
    const container = $(`#${name}`);
    if (container) {
      container.remove();

      // also remove the corresponding hidden input field
      $(`input[name="${prefix}_names[]"][value="${name}"]`).remove();
    } else {
      console.error('DatePeriodAdder: element to remove not found', name);
    }
  };
});
