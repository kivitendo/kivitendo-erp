diag("Show languages");

if(!$sel->get_title("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db})){
  require_ok("../../begin/B004Login.t");
}

$sel->select_frame_ok("relative=up");
$sel->click_ok("link=Sprachen anzeigen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->click_ok("link=elbisch");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->click_ok("action");
$sel->wait_for_page_to_load($lxtest->{timeout});
