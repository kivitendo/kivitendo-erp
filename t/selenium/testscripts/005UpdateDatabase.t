### Update Database

# NOTEST: some preruns for initializing missing parameters
$sel->open($lxtest->{lxadmin});
$sel->click("//input[(\@name=\"action\") and (\@value=\"Datenbankadministration\")]");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->type("dbuser", $lxtest->{dbuser});
$sel->type("dbpasswd", $lxtest->{dbpasswd});
$sel->type("dbuser", $lxtest->{dbuser});
$sel->type("dbhost", $lxtest->{dbhost});
$sel->type("dbport", $lxtest->{dbport});
$sel->type("dbdefault", $lxtest->{dbdefault});
$sel->click("//input[(\@name=\"action\") and (\@value=\"Datenbank aktualisieren\")]");
$sel->wait_for_page_to_load($lxtest->{timeoutlong});
$sel->title_is("Lx-Office ERP Datenbankadministration / Datenbank aktualisieren -");

my $count =0;

while (){ # count the number of radiobuttons
  eval {  $sel->is_checked("//input[(\@id=\"$count\")]"); };
    if ( $@ ) { $count--; last; }; 
  $count++;
}

#TEST: Now run the Tests

$sel->open_ok($lxtest->{lxadmin});
$sel->title_is("Lx-Office ERP Administration -");

#diag('Lock the system');
#$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"System sperren\")]");
#$sel->wait_for_page_to_load_ok($lxtest->{timeout});

diag('Update the database');

$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Datenbankadministration\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP / Datenbankadministration -");
$sel->type_ok("dbuser", $lxtest->{dbuser});
$sel->type_ok("dbpasswd", $lxtest->{dbpasswd});
$sel->type_ok("dbuser", $lxtest->{dbuser});
$sel->type_ok("dbhost", $lxtest->{dbhost});
$sel->type_ok("dbport", $lxtest->{dbport});
$sel->type_ok("dbdefault", $lxtest->{dbdefault});
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Datenbank aktualisieren\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeoutlong});
$sel->title_is("Lx-Office ERP Datenbankadministration / Datenbank aktualisieren -");

for (my $i=0; $i <= $count; $i++){
  $sel->uncheck_ok("//input[(\@id=\"$i\")]");
}

#$sel->click_ok("//input[\@value=\"$lxtest->{db}\"]");
#$sel->check_ok("//input[\@name=\"db$lxtest->{db}\"]");
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
$sel->title_like( qr/Lx-Office ERP Datenbankadministration/ );

#diag('Unlock the system');
#$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"System entsperren\")]");
#$sel->wait_for_page_to_load_ok($lxtest->{timeout});
#$sel->title_is("Lx-Office ERP Administration -");

