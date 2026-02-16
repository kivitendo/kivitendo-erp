function custom_time(h,m) {
  var time = new Date();
  time.setHours(h,m);
  return time;
}

QUnit.test("kivi.parse_time function for German time style with colon", function( assert ) {
  assert.equalTimes = function(actual, expected, message) {
    console.log(this);
    var result = (expected === undefined && actual === undefined)
                || (expected === null      && actual === null)
                || (expected instanceof Date && actual instanceof Date &&
                    expected.getHours()   == actual.getHours() &&
                    expected.getMinutes() == actual.getMinutes());

    this.push( {
        result: result,
        actual: actual,
        expected: expected,
        message: message
    } );
  }

  kivi.setup_formats({ times: "hh:mm" });

  assert.equalTimes(kivi.parse_time("12:34"), custom_time(12,34));
  assert.equalTimes(kivi.parse_time("10:00"), custom_time(10,0));
  assert.equalTimes(kivi.parse_time("      12 :  23  ") - custom_time(12,23));

  assert.equalTimes(kivi.parse_time("00:20"), custom_time(0,20));

  assert.equalTimes(kivi.parse_time("23:60"), custom_time(23,60));

  assert.equalTimes(kivi.parse_time("1142"), custom_time(11,42));

  assert.equalTimes(kivi.parse_time("Totally Invalid!"), undefined);
  assert.equalTimes(kivi.parse_time("."), undefined);
  assert.equalTimes(kivi.parse_time(".."), undefined);
  assert.equalTimes(kivi.parse_time(":"), undefined);
  assert.equalTimes(kivi.parse_time("::"), undefined);
  assert.equalTimes(kivi.parse_time("aa:bb"), undefined);
  assert.equalTimes(kivi.parse_time("aasd:bbaf"), undefined);
  assert.equalTimes(kivi.parse_time(""), null);
  assert.equalTimes(kivi.parse_time("0"), new Date());
  assert.equalTimes(kivi.parse_time("29:20008"), custom_time(29,20008));
});

