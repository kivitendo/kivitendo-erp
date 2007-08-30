if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Create Account");

$sel->select_frame_ok("relative=up");
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Konto erfassen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->type_ok("accno", "000000000001");
$sel->type_ok("description", "TestSeleniumKonto");
$sel->select_ok("AccountType", "label=Aktiva/Mittelverwendung (A)");
$sel->click_ok("AR");
$sel->click_ok("AP");
$sel->click_ok("IC");
$sel->click_ok("AR_amount");
$sel->click_ok("AR_paid");
$sel->click_ok("AR_tax");
$sel->click_ok("AP_amount");
$sel->click_ok("AP_paid");
$sel->click_ok("AP_tax");
$sel->click_ok("IC_sale");
$sel->click_ok("IC_cogs");
$sel->click_ok("IC_taxpart");
$sel->click_ok("IC_income");
$sel->click_ok("IC_expense");
$sel->click_ok("IC_taxservice");
$sel->select_ok("pos_eur", "label=05. Ausserordentliche Erträge");
$sel->select_ok("pos_bwa", "label=05. So.betr.Erlöse");
$sel->select_ok("pos_bilanz", "label=02.");
$sel->click_ok("datevautomatik");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok("30000");
$sel->is_element_present_ok("link=000000000001");
$sel->is_text_present_ok("TestSeleniumKonto");
1;