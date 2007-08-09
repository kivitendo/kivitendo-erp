### Login

diag("Logout");

$sel->select_frame_ok("relative=up") if(!$sel->is_element_present_ok("//img"));
$sel->click_ok("link=abmelden");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office Version ".$lxtest->{version});