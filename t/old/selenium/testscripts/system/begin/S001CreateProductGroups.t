if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Create product groups");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Warengruppe erfassen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->type_ok("partsgroup", "TestSeleniumWarengruppe1");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->type_ok("partsgroup", "TestSeleniumWarengruppe2");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("relative=up");
  $sel->click_ok("link=Warengruppen anzeigen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe1");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe2");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->type_ok("partsgroup", "TestSeleniumWarengruppe3");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe3");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;