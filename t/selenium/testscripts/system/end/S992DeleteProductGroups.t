if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);  
}

diag("Delete product groups");

SKIP: {
  start_login();
  $sel->click_ok("link=Warengruppen anzeigen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe1");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});

  skip("Produktgruppen, die noch benutzt werden, können nicht gelöscht werden!", 10) if(!$sel->is_element_present("document.forms[0].action[1]","Löschen"));
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe2");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  
  skip("Produktgruppen, die noch benutzt werden, können nicht gelöscht werden!", 6) if($sel->get_value("document.forms[0].action[1]") ne "Löschen");
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=TestSeleniumWarengruppe3");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  
  skip("Produktgruppen, die noch benutzt werden, können nicht gelöscht werden!", 2) if($sel->get_value("document.forms[0].action[1]") ne "Löschen");
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;