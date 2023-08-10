function BookingModel(data) {
  var self = this;

  var precision = 2;

  self.selected         = ko.observable(false);  // user selected this element

  self.acc_trans_id     = data.acc_trans_id;
  self.accno            = data.accno;
  self.description      = data.description;
  self.reference        = data.reference;
  self.itime            = data.itime; // only used for loaded groups?
  self.formatted_itime  = data.formatted_itime; // only used for loaded groups?

  // amounts
  self.amount           = Number(data.amount); // amount in db format
  self.debit            = Number(data.debit);
  self.credit           = Number(data.credit);

  self.orig_transdate   = data.transdate; // unformatted date, needed when matching transdate filter

  self.transdate        = ko.observable(kivi.parse_date(data.transdate)).extend( { formatted: function(date) {
    return kivi.format_date(date);
  } });
  // maybe directly add/precompute self.transdate_gettime, as we often use getTime() when comparing dates

  self.cleared_group_id = ko.observable(data.cleared_group_id); // will be null or int. needs to be updated if json create_cleared_group was successful

  self.cleared = ko.computed(function() {
    return self.cleared_group_id() !== null ? true : false
  }).extend({ formatted: function(val) {
    return val ? '✓' : '';
  } });

  self.gegen_chart_accnos = data.gegen_chart_accnos;

  self.employee    = data.employee;

  self.project     = data.projectnumber === null ? null : data.projectnumber + ' ' + data.projectdescription;
  self.project_id  = ko.observable(Number(data.project_id));

  self.toggle_selected = function() {
    self.selected( !self.selected() );
  }

  // calculate class for css
  self.xclass = ko.computed(function() {
    if ( self.cleared() ) {
      return 'cleared';
    } else {
      return self.selected() ? 'selected' : undefined;
    }
  });
}

// the main ViewModel
var BookingListViewModel = (function() {
  var self = this;

  self.precision = ko.observable(2);  // used by formatted_amount bindingHandler

  self.bookings = ko.observableArray([])
    .extend({ fibu_sums: true, trackArrayChanges: true });
  // fibu_sums adds bookings.debitSum, bookings.creditSum

  self.selectedChartId = ko.observable(undefined); // bound to input of chartpicker. maybe make a computed and switch between true or false depending on whether value is seted?
  // doesn't really work as a two-way binding, as it doesn't set dummy chart.displayable_name
  self.selectedChart = ko.observable(); // contains the chart fat item

  self.calink = ko.computed(function() {
    if ( self.selectedChart() !== undefined ) {
      return "ca.pl?action=list_transactions&method=cash&accno=" + self.selectedChart().accno;
    } else {
      return undefined;
    }
  });

  self.redirect_chartlist = function() {
    if ( self.calink() !== undefined ) {
      window.location.href = self.calink();
    }
  }

  self.selectedBookings = ko.computed(function() {
    return ko.utils.arrayFilter(self.bookings(), function(booking) {
      return booking.selected();
    });
  }).extend({ fibu_sums: true });

  self.show_filter = ko.observable(true);

  // settings
  self.hideCleared                  = ko.observable(false); // whether to filter out cleared booking groups
  self.automaticClearing            = ko.observable(false); // automatically created a cleared_group when sum(amount) == 0

  // filters
  self.automaticAmountFiltering     = ko.observable(false); // when clicking on a line, filter all lines which have the same amount (with opposite sign)
  self.automaticDateFiltering       = ko.observable(false); // when clicking on a line, filter all lines with the same date
  self.automaticReferenceFiltering  = ko.observable(false);
  self.automaticProjectFiltering    = ko.observable(false);
  self.automaticEmployeeFiltering   = ko.observable(false);
  self.automaticDepartmentFiltering = ko.observable(false);

  self.hasAutomaticFiltering = ko.computed(function() {
    self.automaticAmountFiltering()    ||
    self.automaticDateFiltering()      ||
    self.automaticReferenceFiltering() ||
    self.automaticEmployeeFiltering()  ||
    self.automaticProjectFiltering()   ||
    self.automaticDepartmentFiltering()
  });
   
  self.clicked_booking = ko.observable(); // needed for column line filters

  self.resetClickedBooking = function() {
    self.clicked_booking(undefined);
  }

  self.selectedClearedBookings = ko.observableArray().extend({ fibu_sums: true, trackArrayChanges: true }); // tAC needed?

  self.isClearedGroupSelected = ko.computed(function() {
    return self.selectedClearedBookings.hasBookings();
  });

  self.showSelectedBookings = ko.computed(function() {
    return self.selectedBookings.hasBookings() && !self.isClearedGroupSelected();
  });

  // <!-- fuzzy settings with default values-->
  self.fuzzyDateFilter   = ko.observable(false);
  self.fuzzyDateDays     = ko.observable(2);
  self.fuzzyAmountFilter = ko.observable(false);
  self.fuzzyAmount       = ko.observable(10);

  self.fuzzyAmountFormatted = ko.computed({
    read: function() {
      return kivi.format_amount(self.fuzzyAmount(), 0);
    },
    write: function(formattedAmount) {
      var parsed_amount = kivi.parse_amount(formattedAmount) || 1;  // if user enters 0, assume he wants to disable fuzzyness, silently make it 1 to prevent divbyzero
      self.fuzzyAmount(parsed_amount);
    },
    owner: self
  });

  // input fields for Column filters, searching inside results
  self.searchReference  = ko.observable('');
  self.searchTransdate  = ko.observable(null);
  self.searchGegenChart = ko.observable('');
  self.searchEmployee   = ko.observable('');
  self.searchProject    = ko.observable(undefined);
  self.searchAmount     = ko.observable('0,00').extend({ to_kivitendo_not_zero_reformat: 2, throttle: 300 }); // will not display anything if value is 0

  self.hasColumnFilter= ko.computed(function() {
    return (
      self.searchTransdate()  !== null      ||
      self.searchReference()  !== ''        ||
      self.searchGegenChart() !== ''        ||
      self.searchEmployee()   !== ''        ||
      ( self.searchAmount()   !== '' && self.searchAmount()  !== undefined ) || 
      ( self.searchProject()  !== '' && self.searchProject() !== undefined )
     );
   });

  self.resetColumnFilters = function() {
    self.searchTransdate(null);
    self.searchReference('');
    self.searchGegenChart('');
    self.searchEmployee('');
    self.searchAmount(undefined);
    self.searchProject('');
  }

  // ACTIONS

  // action that happens when clicking on a booking
  self.click = function(booking) {
    if ( booking.cleared() ) {
      // if there are already selected elements
      // * switch group if different group_id
      // * toggle group if save group_id
      if ( self.selectedClearedGroupId() === booking.cleared_group_id() ) {
        self.selectedClearedBookings.removeAll();
      } else {
        self.get_cleared_group(booking.cleared_group_id());
      }
    } else {
      if ( self.isClearedGroupSelected() ) {
        self.selectedClearedBookings.removeAll();
      }
      booking.toggle_selected();

      if ( booking.selected() ) {
        self.clicked_booking(booking);
      } else {
        self.resetClickedBooking();
      }
    }
  }

  self.filteredBookings = ko.computed(function () {
    return ko.utils.arrayFilter(self.bookings(), function (booking) {
      return (
                booking.selected()  // always display any line that was selected, regardless of filter

                ||

                (
                     !( self.hideCleared() && booking.cleared() )
                  && // header filters (manual): transdate, reference, gegenchart, employee, department, project
                     (
                          // transdate
                          (    self.searchTransdate() === null   // empty date
                            || booking.transdate().getTime() === self.searchTransdate().getTime()
                            || (
                                    self.fuzzyDateFilter() && self.searchTransdate() && self.fuzzyDateDays() > 0
                                 && ((Math.abs( (self.searchTransdate() - booking.transdate())/(86400000) )) <= self.fuzzyDateDays())
                               )
                          )
                       && // reference
                          (    self.searchReference() && self.searchReference().length == 0
                            || booking.reference.toLowerCase().indexOf(self.searchReference().toLowerCase()) > -1
                          )
                       && // amount
                          // value in searchAmount, 2 modes possible: fuzzy mode or exact mode
                          ( self.searchAmount() === undefined
                            ||
                            (
                              ( self.fuzzyAmountFilter()
                              &&
                                (
                                 ( Math.abs(Number(booking.amount)) <= Math.abs(kivi.parse_amount(self.searchAmount())) * (1 + Number(self.fuzzyAmount()/100)) )
                                   &&
                                 ( Math.abs(Number(booking.amount)) >= Math.abs(kivi.parse_amount(self.searchAmount())) * (1 - Number(self.fuzzyAmount()/100)) )
                                )
                              )
                              ||
                              (
                                Math.abs(Number(booking.amount)) === Math.abs(Number(kivi.parse_amount(self.searchAmount())))
                              )
                            )
                          )
                       && // employee
                          (    self.searchEmployee().length == 0
                            || booking.employee.toLowerCase().indexOf (self.searchEmployee().toLowerCase()) > -1
                          )
                       && // project
                          (  ( self.searchProject() === undefined || self.searchProject() === null || self.searchProject() === '' )
                             || booking.project_id() ===  Number(self.searchProject())
                          )
                       && // gegenchart
                          (    self.searchGegenChart().length == 0
                            || booking.gegen_chart_accnos.toLowerCase().indexOf (self.searchGegenChart().toLowerCase()) > -1
                          )
                     )
                  && ( // automatic click filters (automatic)
                       ( // skip this whole section if nothing is selected and no automatic matching filters are selected
                         !self.selectedBookings.hasBookings() // skip all automatic click filter checks if nothing is selected
                         ||
                         // also skip all automatic click filters if all automatic click filters are inactive
                         !self.hasAutomaticFiltering
                       )
                       ||
                       (  // individual automatic matching filters, we have already checked that self.clicked_booking() is valid
                         1 === 1
                         && ( // employee filtering
                             !self.automaticEmployeeFiltering()
                             ||
                             (    self.automaticEmployeeFiltering()
                               && self.clicked_booking()
                               && booking.employee === self.clicked_booking().employee
                             )
                            )

                         && ( // reference filtering
                               !self.automaticReferenceFiltering()
                             ||
                               (    self.automaticReferenceFiltering()
                                 && self.clicked_booking()
                                 && booking.reference === self.clicked_booking().reference
                               )
                            )

                         && ( // project filtering
                              !self.automaticProjectFiltering()
                             ||
                               // booking.project_id should always be defined, but may be 0, match all bookings without project_id (also 0)
                               ( self.automaticProjectFiltering()
                                 && self.clicked_booking()
                                 && booking.project_id() === self.clicked_booking().project_id()
                               )
                            )

                         && ( // date filtering
                               !self.automaticDateFiltering()
                             ||
                               (
                                 (    self.automaticDateFiltering()
                                   && self.clicked_booking()
                                   && ( !self.fuzzyDateFilter()
                                        && self.clicked_booking().transdate().getTime() === booking.transdate().getTime()
                                      )
                                      ||
                                      (
                                           self.fuzzyDateFilter() && self.fuzzyDateDays() > 0
                                        && ((Math.abs( (self.clicked_booking().transdate() - booking.transdate())/(86400000) )) <= self.fuzzyDateDays())
                                      )
                                      ||
                                      (
                                           self.fuzzyDateFilter()
                                        && self.fuzzyDateDays() === '0'
                                        && self.clicked_booking().transdate().getTime() === booking.transdate().getTime()
                                      )
                                  )
                               )
                            )

                         && ( // amount filtering
                                 !self.automaticAmountFiltering()
                              ||
                                 (
                                   ( self.automaticAmountFiltering()
                                     && self.clicked_booking()
                                     && self.selectedBookings.hasBookings()
                                     &&  (
                                           !self.fuzzyAmountFilter()
                                           &&
                                           Math.abs(self.clicked_booking().amount) === Math.abs(booking.amount)
                                           &&
                                           Math.sign(self.clicked_booking().amount) !== Math.sign(booking.amount)
                                         )
                                         ||
                                         (
                                           self.fuzzyAmountFilter()
                                           &&
                                           Math.sign(self.clicked_booking().amount) !== Math.sign(booking.amount)
                                           &&
                                           ( Math.abs(self.selectedBookings.saldo()) / Math.abs(Number(booking.amount)) > (1- Number(self.fuzzyAmount()/100)) )
                                           &&
                                           ( Math.abs(self.selectedBookings.saldo()) / Math.abs(Number(booking.amount)) < (1+ Number(self.fuzzyAmount()/100)) )
                                         )
                                    )
                                  )
                     ) // end amount filtering
                   ) // end of individual filters
                 ) // automatic click filter
             ) //
      ) // return
    });
  }).extend( { throttle: 300, fibu_sums: true } );

  // <!---------------------------  HEADERS -------------------------------->
  // create headers programmatically 
  self.headers = ko.observable([
    {title: kivi.t8('Transdate')      , key: 'transdate'         , datatype: 'date'   , cssClass: ''        },
    {title: kivi.t8('Reference')      , key: 'reference'         , datatype: 'text'   , cssClass: ''        },
    {title: kivi.t8('Debit')          , key: 'amount'            , datatype: 'numeric', cssClass: 'numeric' },
    {title: kivi.t8('Credit')         , key: 'amount'            , datatype: 'numeric', cssClass: 'numeric' },
    {title: kivi.t8('Contra accounts'), key: 'gegen_chart_accnos', datatype: 'text'   , cssClass: ''        },
    {title: kivi.t8('Employee')       , key: 'employee'          , datatype: 'text'   , cssClass: ''        },
    {title: kivi.t8('Project')        , key: 'project_id'        , datatype: 'numeric', cssClass: ''        },
    {title: kivi.t8('Cleared')        , key: 'cleared'           , datatype: 'boolean', cssClass: ''        },
  ]);

  self.sortHeader = ko.observable(self.headers[0]);
  self.sortDirection = ko.observable(1);
  self.toggleSort = function (header) {
    if (header === self.sortHeader()) {
        self.sortDirection(self.sortDirection() * -1);
    } else {
        self.sortHeader(header);
        self.sortDirection(1);
    }
  };

  // use a computed to subscribe to both self.sortHeader() and self.sortDirection()
  self.sortBookings = ko.computed(function () {
      var sortHeader = self.sortHeader(),
          dir = self.sortDirection(),
          tempBookings = self.bookings(),
          prop = sortHeader ? sortHeader.key : "";

      if (!prop) return;
      tempBookings.sort(function (a, b) {
          var va = ko.unwrap(a[prop]),
              vb = ko.unwrap(b[prop]);
          if ( sortHeader.key === 'amount' ) {
            va = Math.abs(va);
            vb = Math.abs(vb);
          };
          return va < vb ? -dir : va > vb ? dir : 0;
      });
      self.bookings.notifySubscribers();
  });

  // where the group_id of the currently selected cleared group is stored
  self.selectedClearedGroupId = ko.computed( function() {
    if ( self.isClearedGroupSelected() ) {
      return self.selectedClearedBookings()[0].cleared_group_id();
    } else {
      return undefined;
    }
  });

  // <!-- behaviour -->

  self.deselectAll = function() {
    ko.utils.arrayForEach(self.selectedBookings(), function(booking) {
      if ( booking.selected() ) {
        booking.selected(false);
      }
    });
  };

  self.selectAll = function() {
    ko.utils.arrayForEach(self.filteredBookings(), function(booking) {
      if ( !booking.selected() ) {
        booking.selected(true);
      }
    })
  };

  self.deselectClearedGroup = function() {
    self.selectedClearedGroupId(null);
    self.selectedClearedBookings([]);
    self.resetClickedBooking();
  };


  // <!--------- ajax actions ---------------------------------------------------->
  // <!-- create_cleared_group, remove_cleared_group, get_cleared_group, update -->

  self.create_cleared_group = function() {
    if ( self.selectedBookings().length == 0 ) {
      alert("create_cleared_group called with 0 selectedBookings, do nothing and return");
      return;
    };
    $.ajax({
      url: 'controller.pl?action=Clearing/create_cleared_group.json',
      type: 'POST',
      data: ko.toJSON(self.selectedBookings()),
      contentType: 'application/json; charset=utf-8',
      dataType: 'json',
      async: false,
      success: function(data) {
        kivi.eval_json_result(data);
        self.resetClickedBooking();
        self.update();
      },
      error: function(data) {
        alert(data);
      }
    });
  };

  self.remove_cleared_group = function() {
    var current_cleared_group_id = self.selectedClearedGroupId();
    $.ajax({
      url: 'controller.pl?action=Clearing/remove_cleared_group.json',
      type: 'POST',
      data: ko.toJSON(self.selectedClearedBookings()),
      contentType: 'application/json; charset=utf-8',
      dataType: 'json',
      async: false,
      success: function(data) {
        self.selectedClearedBookings([]);
        kivi.eval_json_result(data); // flash

        ko.utils.arrayForEach(self.bookings(), function(booking) {
          if (booking.cleared_group_id() === current_cleared_group_id) {
            booking.cleared_group_id(null);
          }
        }); //notify
        self.resetClickedBooking();
      },
      error: function(data) {
        alert('something went wrong');
      }
    });
  }; // end of removed_cleared_group

  self.get_cleared_group = function(cleared_group_id) {
    var controller = 'controller.pl?action=Clearing/fetch_cleared_group';
    $.getJSON(controller + '&cleared_group_id=' + cleared_group_id, function(data) {
      self.selectedClearedBookings( ko.utils.arrayMap(data, function(item) { return new BookingModel(item) }) )
    })
  };

  self.update = function() {
    // kivi.clear_flash('error', 5000);
    if ( !self.selectedChartId() ) {
      self.bookings([]);
      kivi.display_flash('error', kivi.t8('No chart selected'),0);
      $("#chart_id_name").focus();
      return 0;
    }
    var controller = 'controller.pl?action=Clearing/list';
    var chart_id = $("#chart_id").val();

    var filterdata = $('#clearing_filter').serialize()

    var url = controller + '&' + 'chart_id=' + chart_id + '&' + filterdata; 
    $.getJSON(url, function(data) {
      self.bookings( ko.utils.arrayMap(data, function(item) { return new BookingModel(item) }) )
    })
  };

  self.init = function () {
    ko.applyBindings(BookingListViewModel);
  };
  $(init);

  // the returns are exposed to wm namespace!
  return {
    update: update,
    click: click,

    create_cleared_group: create_cleared_group,
    remove_cleared_group: remove_cleared_group,
    deselectClearedGroup: deselectClearedGroup,

    selectedBookings: selectedBookings,
    filteredBookings: filteredBookings,
    selectedChartId: selectedChartId,
    selectedChart: selectedChart,
    selectedClearedGroupId: selectedClearedGroupId,

    deselectAll: deselectAll,

    searchProject: searchProject,

    headers: headers,
    sortHeader: sortHeader,

    hideCleared: hideCleared,

    toggleSort: toggleSort,

    automaticAmountFiltering: automaticAmountFiltering,
    automaticDateFiltering: automaticDateFiltering,
    automaticReferenceFiltering: automaticReferenceFiltering,
    automaticProjectFiltering: automaticProjectFiltering,
    automaticEmployeeFiltering: automaticEmployeeFiltering,
    automaticDepartmentFiltering: automaticDepartmentFiltering,

    automaticClearing: automaticClearing
  };
})();


$( document ).ready(function() {

  $('#chart_id').on('change', function(event) {
    BookingListViewModel.update();
  });

  $('#chart_id').on('set_item:ChartPicker', function (e, item) {
    self.selectedChartId(item.id)
    self.selectedChart(item)
  });

  $('#clearing_filter').on('change', 'input', function() {
    $('form#clearing_filter').submit();
  });

  $('#project_id').change( function() {
    BookingListViewModel.searchProject(  $('#project_id').val() );
  });

  $('#automaticClearing').hover( function() { $('#automatic_clearing_info').toggle() });

  $(document).keyup(function(event){
    var keycode = (event.keyCode ? event.keyCode : event.which);
    if(keycode == '13') { <!-- enter -->
      if ( BookingListViewModel.selectedBookings.hasBookings() && BookingListViewModel.selectedBookings.saldo() == 0 ) {
        BookingListViewModel.create_cleared_group();
      }
    }
    if(keycode == '27') { <!-- ESC -->
      if ( BookingListViewModel.selectedBookings.hasBookings() ) {
        BookingListViewModel.deselectAll();
      }
    }
  });

  $('#reset_form_filter').click(function() {
    document.getElementById("clearing_filter").reset();
  });

  // automatically call create_cleared_group when certain conditions are met:
  BookingListViewModel.selectedBookings.saldo.subscribe(function(new_sum) {
    if (    BookingListViewModel.automaticClearing()
         && BookingListViewModel.selectedBookings.hasBookings()
         && new_sum == 0 
       ) {
      BookingListViewModel.create_cleared_group();
    }
  });
});
