function today() {
  var today = new Date();
  today.setMilliseconds(0);
  today.setSeconds(0);
  today.setMinutes(0);
  today.setHours(0);
  return today;
};

QUnit.test("kivi.parse_date function for German date style with dots", function( assert ) {
  kivi.setup_formats({ dates: "dd.mm.yy" });

  assert.deepEqual(kivi.parse_date("01.01.2007"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("1.1.2007"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("      01 .  1. 2007   "), new Date(2007, 0, 1));

  assert.deepEqual(kivi.parse_date("29.02.2008"), new Date(2008, 1, 29));

  assert.deepEqual(kivi.parse_date("11.12.2014"), new Date(2014, 11, 11));

  assert.deepEqual(kivi.parse_date("25.12."), new Date((new Date).getFullYear(), 11, 25));
  assert.deepEqual(kivi.parse_date("25.12"), new Date((new Date).getFullYear(), 11, 25));

  assert.deepEqual(kivi.parse_date("2512"), new Date((new Date).getFullYear(), 11, 25));
  assert.deepEqual(kivi.parse_date("25122015"), new Date(2015, 11, 25));
  assert.deepEqual(kivi.parse_date("251215"), new Date(2015, 11, 25));
  assert.deepEqual(kivi.parse_date("25"), new Date((new Date).getFullYear(), (new Date).getMonth(), 25));
  assert.deepEqual(kivi.parse_date("1"), new Date((new Date).getFullYear(), (new Date).getMonth(), 1));
  assert.deepEqual(kivi.parse_date("01"), new Date((new Date).getFullYear(), (new Date).getMonth(), 1));

  assert.deepEqual(kivi.parse_date("Totally Invalid!"), undefined);
  assert.deepEqual(kivi.parse_date(":"), undefined);
  assert.deepEqual(kivi.parse_date("::"), undefined);
  assert.deepEqual(kivi.parse_date("."), today());
  assert.deepEqual(kivi.parse_date(".."), today());
  assert.deepEqual(kivi.parse_date(""), null);
  assert.deepEqual(kivi.parse_date("0"), new Date());
  assert.deepEqual(kivi.parse_date("00"), new Date());
  assert.deepEqual(kivi.parse_date("29.02.20008"), undefined);
});

QUnit.test("kivi.parse_date function for German date style with slashes", function( assert ) {
  kivi.setup_formats({ dates: "dd/mm/yy" });

  assert.deepEqual(kivi.parse_date("01/01/2007"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("1/1/2007"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("      01 /  1/ 2007   "), new Date(2007, 0, 1));

  assert.deepEqual(kivi.parse_date("29/02/2008"), new Date(2008, 1, 29));

  assert.deepEqual(kivi.parse_date("11/12/2014"), new Date(2014, 11, 11));

  assert.deepEqual(kivi.parse_date("25/12/"), new Date((new Date).getFullYear(), 11, 25));
  assert.deepEqual(kivi.parse_date("25/12"), new Date((new Date).getFullYear(), 11, 25));

  assert.deepEqual(kivi.parse_date("/"), today());
  assert.deepEqual(kivi.parse_date("//"), today());

  assert.deepEqual(kivi.parse_date("Totally Invalid!"), undefined);
});

QUnit.test("kivi.parse_date function for American date style", function( assert ) {
  kivi.setup_formats({ dates: "mm/dd/yy" });

  assert.deepEqual(kivi.parse_date("01/01/2007"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("1/1/2007"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("      01 /  1/ 2007   "), new Date(2007, 0, 1));

  assert.deepEqual(kivi.parse_date("02/29/2008"), new Date(2008, 1, 29));

  assert.deepEqual(kivi.parse_date("12/11/2014"), new Date(2014, 11, 11));

  assert.deepEqual(kivi.parse_date("12/25/"), new Date((new Date).getFullYear(), 11, 25));
  assert.deepEqual(kivi.parse_date("12/25"), new Date((new Date).getFullYear(), 11, 25));

  assert.deepEqual(kivi.parse_date("/"), today());
  assert.deepEqual(kivi.parse_date("//"), today());

  assert.deepEqual(kivi.parse_date("Totally Invalid!"), undefined);
});

QUnit.test("kivi.parse_date function for ISO date style", function( assert ) {
  kivi.setup_formats({ dates: "yyyy-mm-dd" });

  assert.deepEqual(kivi.parse_date("2007-01-01"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("2007-1-1"), new Date(2007, 0, 1));
  assert.deepEqual(kivi.parse_date("      2007 - 1     -01   "), new Date(2007, 0, 1));

  assert.deepEqual(kivi.parse_date("2008-02-29"), new Date(2008, 1, 29));

  assert.deepEqual(kivi.parse_date("2014-12-11"), new Date(2014, 11, 11));

  assert.deepEqual(kivi.parse_date("-12-25"), new Date((new Date).getFullYear(), 11, 25));
});

QUnit.test("kivi.format_date function for German date style with dots", function( assert ) {
  kivi.setup_formats({ dates: "dd.mm.yy" });

  assert.deepEqual(kivi.format_date(new Date(2007, 0, 1)), "01.01.2007");
  assert.deepEqual(kivi.format_date(new Date(2008, 1, 29)), "29.02.2008");
  assert.deepEqual(kivi.format_date(new Date(2014, 11, 11)), "11.12.2014");

  assert.deepEqual(kivi.format_date(new Date(undefined, undefined, undefined)), undefined);
});

QUnit.test("kivi.format_date function for German date style with slashes", function( assert ) {
  kivi.setup_formats({ dates: "dd/mm/yy" });

  assert.deepEqual(kivi.format_date(new Date(2007, 0, 1)), "01/01/2007");
  assert.deepEqual(kivi.format_date(new Date(2008, 1, 29)), "29/02/2008");
  assert.deepEqual(kivi.format_date(new Date(2014, 11, 11)), "11/12/2014");

  assert.deepEqual(kivi.format_date(new Date(undefined, undefined, undefined)), undefined);
});

QUnit.test("kivi.format_date function for American date style", function( assert ) {
  kivi.setup_formats({ dates: "mm/dd/yy" });

  assert.deepEqual(kivi.format_date(new Date(2007, 0, 1)), "01/01/2007");
  assert.deepEqual(kivi.format_date(new Date(2008, 1, 29)), "02/29/2008");
  assert.deepEqual(kivi.format_date(new Date(2014, 11, 11)), "12/11/2014");

  assert.deepEqual(kivi.format_date(new Date(undefined, undefined, undefined)), undefined);
});

QUnit.test("kivi.format_date function for ISO date style", function( assert ) {
  kivi.setup_formats({ dates: "yyyy-mm-dd" });

  assert.deepEqual(kivi.format_date(new Date(2007, 0, 1)), "2007-01-01");
  assert.deepEqual(kivi.format_date(new Date(2008, 1, 29)), "2008-02-29");
  assert.deepEqual(kivi.format_date(new Date(2014, 11, 11)), "2014-12-11");

  assert.deepEqual(kivi.parse_date("1225"), new Date((new Date).getFullYear(), 11, 25));
  assert.deepEqual(kivi.parse_date("20151225"), new Date(2015, 11, 25));
  assert.deepEqual(kivi.parse_date("151225"), new Date(2015, 11, 25));
  assert.deepEqual(kivi.parse_date("25"), new Date((new Date).getFullYear(), (new Date).getMonth(), 25));
  assert.deepEqual(kivi.parse_date("1"), new Date((new Date).getFullYear(), (new Date).getMonth(), 1));
  assert.deepEqual(kivi.parse_date("01"), new Date((new Date).getFullYear(), (new Date).getMonth(), 1));

  assert.deepEqual(kivi.parse_date("0"), new Date());
  assert.deepEqual(kivi.parse_date("00"), new Date());

  assert.deepEqual(kivi.parse_date("-"), today());
  assert.deepEqual(kivi.parse_date("--"), today());

  assert.deepEqual(kivi.format_date(new Date(undefined, undefined, undefined)), undefined);
});
