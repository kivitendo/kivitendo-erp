if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete product");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Waren");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->text_is("link=TestWare1", "TestWare1");
  $sel->text_is("link=TestWareSelenium2", "TestWareSelenium2");
  $sel->text_is("link=1", "1");
  $sel->text_is("link=2", "2");
  TODO: {
    local $TODO = "Waren in Rechnungen können nicht gelöscht werden!";
#     $sel->click_ok("link=1");
#     $sel->wait_for_page_to_load_ok($lxtest->{timeout});
#     $sel->click_ok("document.ic.action[3]");
#     $sel->wait_for_page_to_load_ok($lxtest->{timeout});
#     $sel->click_ok("link=TestWareSelenium2");
#     $sel->wait_for_page_to_load_ok($lxtest->{timeout});
#     $sel->click_ok("document.ic.action[3]");
#     $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  }
};
1;