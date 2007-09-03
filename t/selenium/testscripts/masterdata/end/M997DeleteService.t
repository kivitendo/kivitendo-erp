if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete service");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Dienstleistungen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->text_is("link=999", "999");
  $sel->text_is("link=998", "998");
  $sel->text_is("link=Programmierstunde", "Programmierstunde");
  $sel->text_is("link=Telefonstunde", "Telefonstunde");
  $sel->click_ok("link=999");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.ic.action[3]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=Telefonstunde");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.ic.action[3]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;