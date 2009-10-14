require "t/selenium/AllTests.t";

init_server("administration/begin", "system/begin", "masterdata/begin");
  
diag("\n\nUsername: " .  $lxtest->{testuserlogin} . "\n" . "Password: " .  $lxtest->{testuserpasswd} . "\n\n");

1;

