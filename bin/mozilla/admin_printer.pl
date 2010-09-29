use strict;

use SL::Printer;

sub get_login {
  unless ($::form->{login}) {
    get_login_form();
    ::end_of_request();
  }
  return $::form->{login};
}

sub get_login_form {
  my %users = $::auth->read_all_users;

  $::form->header;
  print $::form->parse_html_template('admin_printer/login', {
    users => [ values %users ],
  });
}

sub printer_dispatcher {
      $::lxdebug->dump(0,  "testing", $::form);
  for (qw(get_login_form list_printers add_printer edit_printer save_printer delete_printer list_users)) {
    if ($::form->{$_}) {
      ::call_sub($::locale->findsub($_));
      ::end_of_request()
    }
  }
  die "cannot find sub";
}

sub printer_management {
  &list_printers;
}

sub add_printer {
  $::lxdebug->enter_sub;

  my $login   = get_login();
  my %users   = $::auth->read_all_users;

  $::form->header;
  print $::form->parse_html_template('admin_printer/edit', {
    title   => $::locale->text("Add Printer"),
    printer => { },
    users   => [ values %users ],
  });

  $::lxdebug->leave_sub
}

sub edit_printer {
  $::lxdebug->enter_sub;

  my $login = get_login();
  my $id    = $::form->{id} or $::form->{printer}{id} or &add_printer;
  my %users   = $::auth->read_all_users;

  my $printer = SL::Printer->get_printer(id => $id, login => $login);

  $::form->header;
  print $::form->parse_html_template('admin_printer/edit', {
    title   => $::locale->text("Edit Printer"),
    printer => $printer,
    users   => [ values %users ],
  });

  $::lxdebug->leave_sub;
}

sub list_printers {
  $::lxdebug->enter_sub;

  my $login    = get_login();
  my $printers = SL::Printer->all_printers(login => $login);
  my %users   = $::auth->read_all_users;

  $::form->header;
  print $::form->parse_html_template('admin_printer/list', {
    title        => $::locale->text('Printer'),
    all_printers => $printers,
    edit_link    => build_std_url("login=$login", 'action=edit_printer', 'id='),
    users        => [ values %users ],
  });

  $::lxdebug->leave_sub;
}


sub save_printer {
  $::lxdebug->enter_sub;

  my $login   = get_login();
  my $printer = $::form->{printer} || die 'no printer to save';

  $::form->error($::locale->text('Description missing!'))     unless $printer->{printer_description};
  $::form->error($::locale->text('Printer Command missing!')) unless $printer->{printer_command};

  SL::Printer->save_printer(%$::form);

  list_printers();
  $::lxdebug->leave_sub;
}

sub delete_printer {
  $::lxdebug->enter_sub;

  my $login   = get_login();
  my $printer = $::form->{printer} || die 'no printer to delete';

  SL::Printer->delete_printer(%$::form);
  list_printers();

  $::lxdebug->leave_sub;
}

1;
