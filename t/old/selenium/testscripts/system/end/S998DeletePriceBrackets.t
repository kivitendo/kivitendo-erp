if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete price brackets");
SKIP: {
  start_login();
  
  $sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
  $sel->click_ok("link=Preisgruppen anzeigen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=SeleniumTestPreisgruppe1");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  skip("Preisgruppen, die noch benutzt werden, können nicht gelöscht werden!", 6) if(!$sel->is_element_present("document.forms[0].action[1]","Löschen"));
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=SeleniumTestPreisgruppe2");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  skip("Preisgruppen, die noch benutzt werden, können nicht gelöscht werden!", 2) if(!$sel->is_element_present("document.forms[0].action[1]","Löschen"));
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;