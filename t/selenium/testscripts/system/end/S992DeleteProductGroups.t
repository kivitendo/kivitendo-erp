if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete product groups");
TODO: {
  local $TODO = "Benutzte Preisgruppen können nicht gelöscht werden!";

  if(!$sel->get_title("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db})){
    require_ok("../../begin/B004Login.t");
  }

  $sel->select_frame_ok("relative=up");
  $sel->click_ok("link=Warengruppen anzeigen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe1");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe2");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe3");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
}
1;