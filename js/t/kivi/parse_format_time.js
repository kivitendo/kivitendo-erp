function custom_time(h,m) {
  var time = new Date();
  time.setHours(h,m);
  return time;
}

QUnit.test("kivi.parse_time function for German time style with colon", function( assert ) {
  kivi.setup_formats({ times: "hh:mm" });

  assert.deepEqual(kivi.parse_time("12:34"), custom_time(12,34));
  assert.deepEqual(kivi.parse_time("10:00"), custom_time(10,0));
  assert.deepEqual(kivi.parse_time("      12 :  23  "), custom_time(12,23));

  assert.deepEqual(kivi.parse_time("00:20"), custom_time(0,20));

  assert.deepEqual(kivi.parse_time("23:60"), custom_time(23,60));

  assert.deepEqual(kivi.parse_time("1142"), custom_time(11,42));

  assert.deepEqual(kivi.parse_time("Totally Invalid!"), undefined);
  assert.deepEqual(kivi.parse_time("."), undefined);
  assert.deepEqual(kivi.parse_time(".."), undefined);
  assert.deepEqual(kivi.parse_time(":"), custom_time(0,0));
  assert.deepEqual(kivi.parse_time("::"), undefined);
  assert.deepEqual(kivi.parse_time(""), null);
  assert.deepEqual(kivi.parse_time("0"), new Date());
  assert.deepEqual(kivi.parse_time("29:20008"), custom_time(29,20008));
});

