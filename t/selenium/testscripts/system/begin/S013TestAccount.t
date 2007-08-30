if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Test Account");

$sel->select_frame_ok("relative=up") if (!($sel->get_title() eq "Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db}));
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Konten anzeigen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->click_ok("link=000000000001");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
# Die folegenden Zeilen testen die Checkboxen im Formular, welche nach bestimmten Regeln gelöscht werden.
# Hiefür muß erst ein Konzept erstellt werden, wann eine Checkbox aktiviert ist und wann nicht.

# Test für das erste Konto, bei dem alle Felder deaktiviert werden müssen
isnt($sel->is_checked("//input[(\@name=\"AR_amount\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"AR_paid\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"AR_tax\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"AP_amount\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"AP_paid\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"AP_tax\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"IC_sale\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"IC_cogs\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"IC_taxpart\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"IC_income\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"IC_expense\")]"), 1, "Checkboxcheck");
isnt($sel->is_checked("//input[(\@name=\"IC_taxservice\")]"), 1, "Checkboxcheck");
1;