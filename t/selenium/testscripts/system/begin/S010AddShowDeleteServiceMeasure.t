if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Add show and delete service measure");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Dienstleistungseinheiten");
  $sel->wait_for_page_to_load($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->type_ok("new_name", "ProggerStunde");
  $sel->select_ok("new_base_unit", "label=Std");
  $sel->type_ok("new_factor", "2,0");
  $sel->type_ok("new_localized_" . $lxtest->{lang_id}, "Dinges");
  $sel->type_ok("new_localized_plural_" . $lxtest->{lang_id}, "Dingeses");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load($lxtest->{timeout});
  $sel->click_ok("//tr[6]/td[1]/a/img");
  $sel->wait_for_page_to_load($lxtest->{timeout});
  $sel->click_ok("//tr[5]/td[1]/a[2]/img");
  $sel->wait_for_page_to_load($lxtest->{timeout});
  $sel->click_ok("delete_5");
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load($lxtest->{timeout});
};
1;