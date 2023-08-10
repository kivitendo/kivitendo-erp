// bindingHandlers

ko.bindingHandlers.toggle = {
  init: function(element, valueAccessor) {
    var value = valueAccessor();
    ko.applyBindingsToNode(element, {
      click: function() {
        value(!value());
      }
    });
  }
};

ko.bindingHandlers.formatted_date = {
  update: function(element, valueAccessor, allBindingsAccessor) {
    // console.log('valueAccessor = ' + valueAccessor());
    var value     = ko.utils.unwrapObservable(valueAccessor()) || undefined;
    // console.log("formatted_date value = " + value);
    if ( value !== undefined ) {
      $(element).text( kivi.format_date(value));
    }
  }
};

ko.bindingHandlers.parsed_formatted_date = {
  update: function(element, valueAccessor, allBindingsAccessor) {
    var value     = ko.utils.unwrapObservable(valueAccessor()) || undefined;
    $(element).text( kivi.parse_date(kivi.format_date(value)));
  }
};

ko.bindingHandlers.datepicker = {
    init: function(element, valueAccessor, allBindingsAccessor) {
        var $el = $(element);

        //initialize datepicker with some optional options
        var options = allBindingsAccessor().datepickerOptions || {
          showOn: "button",
          showButtonPanel: true,
          changeMonth: true,
          changeYear: true,
          buttonImage: "image/calendar.png",
          buttonImageOnly: true
        };
        // $.datepicker.setDefaults( $.datepicker.regional[ kivi.myconfg.countrycode ] );
        $el.datepicker(options);

        //handle the field changing
        // debugger;
        ko.utils.registerEventHandler(element, "change", function() {
            // update observable whenever input value changes

            // the change event is fired after datepicker internally sets the date and then updates the input
            // at this point viewModel.mydata (valueAccessor) still contains the old value
            // and we can update/sync it with the value from getpicker.getDate

            // but date may also have been changed manually by user, e.g. using the shortcut 2604

            // console.log('element contains ' + $(element).val());
            // console.log('event: change event on element, setting observable via getDate: ' + $el.datepicker("getDate"));
            var observable = valueAccessor(); // should contain the current date object in viewModel.myData

            var input_date;
            if ( $(element).val() === "" ) {
              // don't try parsing if element is empty
              input_date = null;
            } else {
              console.log('about to parse');
              input_date = kivi.parse_date($(element).val());
              console.log( "isNaN = " + isNaN(input_date.getTime) );
            }

            var picker_date = $el.datepicker("getDate");
            // console.log("input_date = " + kivi.format_date(input_date) + '    picker_date = ' + kivi.format_date(picker_date));
            // console.log("input_date - picker_date = " + (input_date - picker_date));

            // if input was updated via datepicker, getDate will already contain the desired date, use that (observable(picker_date))
            //   and input_date and picker_date will match!
            // but if input was updated manually, use the parsed_date and also update picker

            if ( input_date !== null && picker_date !== null && input_date - picker_date === 0 ) {
              console.log('input_date and picker_date are identical (set by picker), set observable to picker_date');
              observable(picker_date);
            } else if ( input_date === null ) {
              observable(""); // TODO: check that it is a date object, have we validated?
              // console.log('input_date and picker_date differ (input field set manually), set observable to input_date');
            } else {
              observable(input_date); // TODO: check that it is a date object, have we validated?
            }

            // observable(new_date);
            // return;

            // console.log('event: unwrapped observable: ' + ko.unwrap(observable));
            // console.log('event: observable: ' + observable());
            // observable still contains the old date Object from vm
            // debugger;
            // setTimeout(function(){
            //     console.log("running after timeout");
                // observable($el.datepicker("getDate"));
            // }, 10);
        });

        //handle disposal (if KO removes by the template binding)
        ko.utils.domNodeDisposal.addDisposeCallback(element, function() {
            $el.datepicker("destroy");
        });

    },
    update: function(element, valueAccessor) {
        console.log("the value of the observable was changed, so now we need to update the datepicker");
        var value = ko.utils.unwrapObservable(valueAccessor()),
            $el = $(element),
            current = $el.datepicker("getDate");
        var observable = valueAccessor(); // should contain a date object
        // debugger;
        console.log("observabl: " + ko.unwrap(observable));
        console.log("update: value = " + value);
        console.log("update: current = " + current);
        console.log("update: el.val  = " + $el.val());
        console.log("update: el.val  = " + $el.val());

        // if ( isNaN( ko.unwrap(observable())).getTime() ) {
        //   console.log("isNaN");
        // } else {
          // $el.datepicker("setDate", value);
        // }

        // if ( current !== null && $el.val() !== '' ) { //$el.val() !== null && curr) {
        //   var parsed_date = kivi.parse_date($el.val());
        //   var formatted_date = kivi.format_date(parsed_date);
        //   console.log("parsed_date = " + parsed_date + ", formatted_date = " + formatted_date);
        //   $el.datepicker("setDate", parsed_date);
        //   valueAccessor(parsed_date);
        // }
        if (value - current !== 0) {
            console.log('setting date via setDate to ' + value);
            $el.datepicker("setDate", value);
        }
    }
};

ko.bindingHandlers.formatted_amount = {
  update: function(element, valueAccessor, allBindingsAccessor) {
      var value     = ko.utils.unwrapObservable(valueAccessor()) || undefined;
      var precision = ko.utils.unwrapObservable(allBindingsAccessor().precision) || 2;
      var type = ko.utils.unwrapObservable(allBindingsAccessor().type) || '';

      // automatically add class numeric so we don't have to do it in template
      // useful for td
      // debugger;
      if ( element.tagName === 'TD' ) {  // other tagnames: SPAN
        // maybe have it as an option in allBindingsAccessor?, e.g.
        // var numeric = ko.utils.unwrapObservable(allBindingsAccessor().numeric) || '';
        // if ( numeric ) {
        $(element).addClass('numeric');
        // }
      }
      // console.log('updating formatted_amount bH with reference ' + $(element).parent().find('td:eq(1)').html() + ' and value ' + value);
      if ( value !== undefined ) {
        value = + value;
        if ( type === 'cd' ) {
          $(element).text( format_sh(value) );
        } else {
          // console.log('cd');
          var formattedAmount = kivi.format_amount(value, precision);
          $(element).text(formattedAmount);
        }
      } else {
        $(element).text(''); // don't return undefined here, otherwise deselecting the last element won't work (updating sums)
      }
  }
};

// extenders

// adding several properties to target in one extender
ko.extenders.fibu_sums = function (target, unused) {
  // console.log('called fibu_sums extender');
  // target is an array of bookings

  // debugger;
  // create various sums from bookings
  // assumes booking model contains:
  // *  Numbers debit, credit, amount (not observables)
  // *  amount as a Number
  //
  target.debitSum = ko.computed(function () {
    return bookings_sum(target, 'debit');
  });
  target.creditSum = ko.computed(function () {
    return bookings_sum(target, 'credit');
  });
  target.saldo  = ko.computed(function () {
    return bookings_sum(target, true);
  });
  target.saldo_cd = ko.computed(function () {
    return bookings_sum(target, 'cd');
  });
  target.hasBookings = ko.computed(function () {
    return target().length > 0;
  });
  target.isBalanced = ko.computed(function () {
    if ( target().length == 0 )
      return false;
    return bookings_sum(target, true) == 0 ? true : false;
  });
  target.hasCreditSaldo = ko.computed(function () {
    return target.saldo() > 0 ? true : false;
  });
  target.hasDebitSaldo = ko.computed(function () {
    return target.saldo() < 0 ? true : false;
  });

  return target;
};

ko.extenders.to_kivitendo = function (target, precision) {
  target.to_kivitendo = ko.computed(function () {
    return target() === null ? undefined : kivi.format_amount(target(), precision);
 });
};

// ko.extenders.to_kivitendo_rewrite = function(target, precision) {
//     //create a writable computed observable to intercept writes to our observable
//     var result = ko.pureComputed({
//         read: target,
//         write: function(newValue) {
//             var current = target(),
//                 newValueAsNum = isNaN( kivi.parse_amount(newValue)) ? 0 : kivi.parse_amount(newValue),
//                 valueToWrite = kivi.format_amount(newValueAsNum, precision);
//             //only write if it changed
//             if (valueToWrite !== current) {
//                 target(valueToWrite);
//             } else {
//                 //if the rounded value is the same, but a different value was written, force a notification for the current field
//                 if (newValue !== current) {
//                     target.notifySubscribers(valueToWrite);
//                 }
//             }
//         }
//     }).extend({ notify: 'always' });
//
//     //initialize with current value to make sure it is rounded appropriately
//     result(target());
//
//     //return the new computed observable
//     return result;
// };

ko.extenders.to_kivitendo_not_zero_reformat = function(target, precision) {
    //create a writable computed observable to intercept writes to our observable
    var result = ko.pureComputed({
        read: target,  //always return the original observables value
        write: function(newValue) {
            <!-- console.log('changing from ' + target() + ' to ' + newValue + ' &#45;> (' + kivi.format_amount(newValue,2) + ')'); -->
            // console.log('changing from ' + target() + ' to ' + newValue);
            var current = target();
            var formattedNewValue = isNaN(newValue) ? kivi.parse_amount(newValue) : newValue;
            var newValueAsNum = isNaN(formattedNewValue) ? undefined : formattedNewValue;
            var valueToWrite = formattedNewValue ? kivi.format_amount(formattedNewValue, precision) : undefined;
            //only write if it changed
            if (valueToWrite !== current) {
                target(valueToWrite);
            } else {
                //if the rounded value is the same, but a different value was written, force a notification for the current field
                if (newValue !== current) {
                    target.notifySubscribers(valueToWrite);
                }
            }
        }
    }).extend({ notify: 'always' });

    //initialize with current value to make sure it is rounded appropriately
    result(target());

    //return the new computed observable
    return result;
};

// ko.extenders.to_kivitendo_not_zero = function(target, precision) {
//     //create a writable computed observable to intercept writes to our observable
//     var result = ko.pureComputed({
//         read: target,  //always return the original observables value
//         write: function(newValue) {
//             var current = target(),
//                 newValueAsNum = isNaN(newValue) ? undefined : +newValue,
//                 valueToWrite = newValueAsNum ? kivi.format_amount(newValueAsNum, precision) : undefined;
//             //only write if it changed
//             if (valueToWrite !== current) {
//                 target(valueToWrite);
//             } else {
//                 //if the rounded value is the same, but a different value was written, force a notification for the current field
//                 if (newValue !== current) {
//                     target.notifySubscribers(valueToWrite);
//                 }
//             }
//         }
//     }).extend({ notify: 'always' });
//
//    //initialize with current value to make sure it is rounded appropriately
//    result(target());
//
//    //return the new computed observable
//    return result;
//};

ko.extenders.to_amount_cd = function (target, precision) {
  target.to_amount_cd = ko.computed(function () {
    return target() === null ? undefined : format_sh(target())
 });
};

ko.extenders.formatted = function (underlyingObservable, formatFunction) {
  underlyingObservable.formatted = ko.computed(function () {
    return formatFunction(underlyingObservable());
 });
};

// helper functions

function bookings_sum (bookings, type) {
  var total = 0;
  ko.utils.arrayForEach(bookings(), function(booking) {
    if ( type === 'credit' ) {
      total += Number(booking.credit);
    } else if ( type === 'debit' ) {
      total += Number(booking.debit);
    } else {
      total += booking.amount;
    }
  });
  if ( type === 'cd' ) {
    return format_sh(total);
  } else {
    return total.toFixed(5);
  }
}

function format_sh (val) {
  if ( val === null ) {
    return undefined;
  } else {
    if ( val === 0 ) {
      return kivi.format_amount(val,2);
    } else if ( val < 0 ) {
      return kivi.format_amount(val * (-1),2) + ' S';
    } else if ( val > 0 ) {
      return kivi.format_amount(val *  (1),2) + ' H';
    } else {
      return val;
    }
  }
}
