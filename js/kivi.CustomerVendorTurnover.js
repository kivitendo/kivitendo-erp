namespace('kivi.CustomerVendorTurnover', function(ns) {

  ns.show_dun_stat = function(period) {
    if (period === 'y') {
      var url = 'controller.pl?action=CustomerVendorTurnover/count_open_items_by_year&id=' + $('#cv_id').val();
      $('#duns').load(url);
    } else {
      var url = 'controller.pl?action=CustomerVendorTurnover/count_open_items_by_month&id=' + $('#cv_id').val();
      $('#duns').load(url);
    }
  };

  ns.get_invoices = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_invoices&id=' + $('#cv_id').val() + '&db=' + $('#db').val();
    $('#invoices').load(url);
  };

  ns.get_sales_quotations = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_orders&id=' + $('#cv_id').val() + '&db=' + $('#db').val() + '&type=quotation';
    $('#quotations').load(url);
  };

  ns.get_orders = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_orders&id=' + $('#cv_id').val() + '&db=' + $('#db').val() + '&type=order';
    $('#orders').load(url);
  };

  ns.get_letters = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_letters&id=' + $('#cv_id').val() + '&db=' + $('#db').val();;
    $('#letters').load(url);
  };

  ns.get_mails = function() {
    var url = 'controller.pl?action=CustomerVendorTurnover/get_mails&id=' + $('#cv_id').val() + '&db=' + $('#db').val();;
    $('#mails').load(url);
  };

  ns.show_turnover_stat = function(period) {
    let mode = 'year';
    if (period === 'm') mode = 'month';
    const url = 'controller.pl?action=CustomerVendorTurnover/turnover&id=' + $('#cv_id').val() + '&db=' + $('#db').val() + '&mode=' + mode;
    $('#turnovers').load(url);
  };

  ns.show_turnover_chart = function(period, year_for_month) {
    let mode = "month";
    if (period === 'y') {
      mode    = "year";
      year_for_month = undefined;
    } else if (period === 'm') {
      mode    = "month";
    }

    const data = { action: 'CustomerVendorTurnover/turnover.json',
                   id:   $('#cv_id').val(),
                   db:   $('#db').val(),
                   mode: mode,
                   year: year_for_month
                 };
    $.getJSON('controller.pl', data, function( returned_data ) {
      const html = '<canvas id="turnovers_chart"></canvas>';
      $('#turnovers_chart_container').html(html);
      ns.draw_chart(returned_data);
      $("html, body").animate({ scrollTop: $("#turnovers_chart").offset().top }, "slow");
    });
  };

  ns.draw_chart = function(data) {
    // Todos are most probably better done in the perl backend.
    // Todo: fill holes
    // Todo: show amount/paid in one/each bar
    // data = [
    //   {date_part: 2022, netamount: 1234.4},
    //   {date_part: 2022, netamount: 234.4},
    //   {date_part: 2021, netamount: 234.4},
    //   {date_part: 2021, netamount: 34.4},
    //   {date_part: 2020, netamount: 134.4},
    //   {date_part: 2018, netamount: 34.4}
    // ];

    $(data).each(function(idx, elt) {
      elt.date_part = '' + elt.date_part;
    });

    ns.chart(data);
  };

  ns.chart = function(data) {
    const ctx = 'turnovers_chart';
    const chart = new Chart(ctx, {
      type: 'bar',
      data: {
        datasets: [{
          label: kivi.t8('Net.Turnover'),
          data: data,
          backgroundColor: [
            'rgba(255, 99, 132, 0.2)',
            'rgba(54, 162, 235, 0.2)',
            'rgba(255, 206, 86, 0.2)',
            'rgba(75, 192, 192, 0.2)',
            'rgba(153, 102, 255, 0.2)',
            'rgba(255, 159, 64, 0.2)'
          ],
          borderColor: [
            'rgba(255, 99, 132, 1)',
            'rgba(54, 162, 235, 1)',
            'rgba(255, 206, 86, 1)',
            'rgba(75, 192, 192, 1)',
            'rgba(153, 102, 255, 1)',
            'rgba(255, 159, 64, 1)'
          ],
          borderWidth: 1
        }]
      },
      options: {
        scales: {
          y: {
            beginAtZero: true
          }
        },
        parsing: {
          xAxisKey: 'date_part',
          yAxisKey: 'netamount'
        },
        onClick: (e) => {
          const canvasPosition = Chart.helpers.getRelativePosition(e, chart);

          // Substitute the appropriate scale IDs
          const dataX = chart.scales.x.getValueForPixel(canvasPosition.x);
          const dataY = chart.scales.y.getValueForPixel(canvasPosition.y);

          if ((data[dataX].date_part || "").match(/^\d{1,4}$/)) {
            ns.show_turnover_chart('m', data[dataX].date_part);
          } else {
            ns.show_turnover_chart('y');
          }
        }
      }
    });
  };

  ns.sample_chart = function() {
    const ctx = 'chart';
    const myChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Red', 'Blue', 'Yellow', 'Green', 'Purple', 'Orange'],
        datasets: [{
          label: '# of Votes',
          data: [12, 19, 3, 5, 2, 3],
          backgroundColor: [
            'rgba(255, 99, 132, 0.2)',
            'rgba(54, 162, 235, 0.2)',
            'rgba(255, 206, 86, 0.2)',
            'rgba(75, 192, 192, 0.2)',
            'rgba(153, 102, 255, 0.2)',
            'rgba(255, 159, 64, 0.2)'
          ],
          borderColor: [
            'rgba(255, 99, 132, 1)',
            'rgba(54, 162, 235, 1)',
            'rgba(255, 206, 86, 1)',
            'rgba(75, 192, 192, 1)',
            'rgba(153, 102, 255, 1)',
            'rgba(255, 159, 64, 1)'
          ],
          borderWidth: 1
        }]
      },
      options: {
        scales: {
          y: {
            beginAtZero: true
          }
        }
      }
    });
  };

  ns.cv_tabs_init = function () {
    $("#customer_vendor_tabs").on('tabsbeforeactivate', function(event, ui){
      if (ui.newPanel.attr('id') == 'quotations') {
        ns.get_sales_quotations();
      }
      if (ui.newPanel.attr('id') == 'turnover_stat') {
        ns.show_turnover_chart("y");
      }
      return 1;
    });

    $("#customer_vendor_tabs").on('tabscreate', function(event, ui){
      if (ui.panel.attr('id') == 'quotations') {
        ns.get_sales_quotations();
      }
      if (ui.panel.attr('id') == 'turnover_stat') {
        ns.show_turnover_chart("y");
      }
      return 1;
    });
  };

  $(function(){
    ns.cv_tabs_init();
  });
});
