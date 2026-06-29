QUnit.test("kivi.setup_formats date format initialization", function( assert ) {
  kivi.setup_formats({ dates: "dd.mm.yy" });
  assert.deepEqual(kivi._date_format, { sep: '.', d: 0, m: 1, y: 2 } , "German date style with dots");

  kivi.setup_formats({ dates: "dd/mm/yy" });
  assert.deepEqual(kivi._date_format, { sep: '/', d: 0, m: 1, y: 2 } , "German date style with slashes");

  kivi.setup_formats({ dates: "mm/dd/yy" });
  assert.deepEqual(kivi._date_format, { sep: '/', d: 1, m: 0, y: 2 } , "American date style");

  kivi.setup_formats({ dates: "yyyy-mm-dd" });
  assert.deepEqual(kivi._date_format, { sep: '-', d: 2, m: 1, y: 0 } , "ISO date style");

  kivi.setup_formats({ dates: "dd.mm.yy" });
  kivi.setup_formats({ dates: "Totally invalid!" });
  assert.deepEqual(kivi._date_format, { sep: '.', d: 0, m: 1, y: 2 } , "Invalid date style should not change previously-set style");
});

QUnit.test("kivi.setup_formats number format initialization", function( assert ) {
  kivi.setup_formats({ numbers: "1.000,00" });
  assert.deepEqual(kivi._number_format, { decimalSep: ',', thousandSep: '.' } , "German number style with thousands separator");

  kivi.setup_formats({ numbers: "1000,00" });
  assert.deepEqual(kivi._number_format, { decimalSep: ',', thousandSep: '' } , "German number style without thousands separator");

  kivi.setup_formats({ numbers: "1,000.00" });
  assert.deepEqual(kivi._number_format, { decimalSep: '.', thousandSep: ',' } , "English number style with thousands separator");

  kivi.setup_formats({ numbers: "1000.00" });
  assert.deepEqual(kivi._number_format, { decimalSep: '.', thousandSep: '' } , "English number style without thousands separator");

  kivi.setup_formats({ numbers: "1.000,00" });
  kivi.setup_formats({ numbers: "Totally invalid!" });
  assert.deepEqual(kivi._number_format, { decimalSep: ',', thousandSep: '.' } , "Invalid number style should not change previously-set style");
});
