### Logout

diag("Logout");

$sel->select_frame_ok("relative=top");
$sel->click_ok("link=abmelden");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office Version ".$lxtest->{version});