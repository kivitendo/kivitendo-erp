diag("Add product");

if(!$sel->get_title("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db})){
  require_ok("../../begin/B004Login.t");
}

$sel->select_frame_ok("relative=up");
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Projekt erfassen");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->type_ok("projectnumber", "1001");
$sel->type_ok("description", "tausend und eine Nacht");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});