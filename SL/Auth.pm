package SL::Auth;

use constant OK              =>   0;
use constant ERR_PASSWORD    =>   1;
use constant ERR_BACKEND     => 100;

use constant SESSION_OK      =>   0;
use constant SESSION_NONE    =>   1;
use constant SESSION_EXPIRED =>   2;

use Digest::MD5 qw(md5_hex);
use IO::File;
use Time::HiRes qw(gettimeofday);
use List::MoreUtils qw(uniq);

use SL::Auth::DB;
use SL::Auth::LDAP;

use SL::User;
use SL::DBUtils;

sub new {
  $main::lxdebug->enter_sub();

  my $type = shift;
  my $self = {};

  bless $self, $type;

  $self->{SESSION} = { };

  $self->_read_auth_config();

  $main::lxdebug->leave_sub();

  return $self;
}

sub DESTROY {
  my $self = shift;

  $self->{dbh}->disconnect() if ($self->{dbh});
}

sub _read_auth_config {
  $main::lxdebug->enter_sub();

  my $self   = shift;

  my $form   = $main::form;
  my $locale = $main::locale;

  my $code;
  my $in = IO::File->new('config/authentication.pl', 'r');

  if (!$in) {
    $form->error($locale->text('The config file "config/authentication.pl" was not found.'));
  }

  while (<$in>) {
    $code .= $_;
  }
  $in->close();

  eval $code;

  if ($@) {
    $form->error($locale->text('The config file "config/authentication.pl" contained invalid Perl code:') . "\n" . $@);
  }

  if ($self->{module} eq 'DB') {
    $self->{authenticator} = SL::Auth::DB->new($self);

  } elsif ($self->{module} eq 'LDAP') {
    $self->{authenticator} = SL::Auth::LDAP->new($self);
  }

  if (!$self->{authenticator}) {
    $form->error($locale->text('No or an unknown authenticantion module specified in "config/authentication.pl".'));
  }

  my $cfg = $self->{DB_config};

  if (!$cfg) {
    $form->error($locale->text('config/authentication.pl: Key "DB_config" is missing.'));
  }

  if (!$cfg->{host} || !$cfg->{db} || !$cfg->{user}) {
    $form->error($locale->text('config/authentication.pl: Missing parameters in "DB_config". Required parameters are "host", "db" and "user".'));
  }

  $self->{authenticator}->verify_config();

  $self->{session_timeout} *= 1;
  $self->{session_timeout}  = 8 * 60 if (!$self->{session_timeout});

  $main::lxdebug->leave_sub();
}

sub authenticate_root {
  $main::lxdebug->enter_sub();

  my $self           = shift;
  my $password       = shift;
  my $is_crypted     = shift;

  $password          = crypt $password, 'ro' if (!$password || !$is_crypted);
  my $admin_password = crypt "$self->{admin_password}", 'ro';

  $main::lxdebug->leave_sub();

  return $password eq $admin_password ? OK : ERR_PASSWORD;
}

sub authenticate {
  $main::lxdebug->enter_sub();

  my $self = shift;

  $main::lxdebug->leave_sub();

  return $self->{authenticator}->authenticate(@_);
}

sub dbconnect {
  $main::lxdebug->enter_sub(2);

  my $self     = shift;
  my $may_fail = shift;

  if ($self->{dbh}) {
    $main::lxdebug->leave_sub(2);
    return $self->{dbh};
  }

  my $cfg = $self->{DB_config};
  my $dsn = 'dbi:Pg:dbname=' . $cfg->{db} . ';host=' . $cfg->{host};

  if ($cfg->{port}) {
    $dsn .= ';port=' . $cfg->{port};
  }

  $main::lxdebug->message(LXDebug::DEBUG1, "Auth::dbconnect DSN: $dsn");

  $self->{dbh} = DBI->connect($dsn, $cfg->{user}, $cfg->{password}, { 'AutoCommit' => 0 });

  if (!$may_fail && !$self->{dbh}) {
    $main::form->error($main::locale->text('The connection to the authentication database failed:') . "\n" . $DBI::errstr);
  }

  $main::lxdebug->leave_sub();

  return $self->{dbh};
}

sub dbdisconnect {
  $main::lxdebug->enter_sub();

  my $self = shift;

  if ($self->{dbh}) {
    $self->{dbh}->disconnect();
    delete $self->{dbh};
  }

  $main::lxdebug->leave_sub();
}

sub check_tables {
  $main::lxdebug->enter_sub();

  my $self    = shift;

  my $dbh     = $self->dbconnect();
  my $query   = qq|SELECT COUNT(*) FROM pg_tables WHERE (schemaname = 'auth') AND (tablename = 'user')|;

  my ($count) = $dbh->selectrow_array($query);

  $main::lxdebug->leave_sub();

  return $count > 0;
}

sub check_database {
  $main::lxdebug->enter_sub();

  my $self = shift;

  my $dbh  = $self->dbconnect(1);

  $main::lxdebug->leave_sub();

  return $dbh ? 1 : 0;
}

sub create_database {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my %params = @_;

  my $cfg    = $self->{DB_config};

  if (!$params{superuser}) {
    $params{superuser}          = $cfg->{user};
    $params{superuser_password} = $cfg->{password};
  }

  $params{template} ||= 'template0';
  $params{template}   =~ s|[^a-zA-Z0-9_\-]||g;

  my $dsn = 'dbi:Pg:dbname=template1;host=' . $cfg->{host};

  if ($cfg->{port}) {
    $dsn .= ';port=' . $cfg->{port};
  }

  $main::lxdebug->message(LXDebug::DEBUG1, "Auth::create_database DSN: $dsn");

  my $dbh = DBI->connect($dsn, $params{superuser}, $params{superuser_password});

  if (!$dbh) {
    $main::form->error($main::locale->text('The connection to the template database failed:') . "\n" . $DBI::errstr);
  }

  my $charset    = $main::dbcharset;
  $charset     ||= Common::DEFAULT_CHARSET;
  my $encoding   = $Common::charset_to_db_encoding{$charset};
  $encoding    ||= 'UNICODE';

  my $query = qq|CREATE DATABASE "$cfg->{db}" OWNER "$cfg->{user}" TEMPLATE "$params{template}" ENCODING '$encoding'|;

  $main::lxdebug->message(LXDebug::DEBUG1, "Auth::create_database query: $query");

  $dbh->do($query);

  if ($dbh->err) {
    my $error = $dbh->errstr();

    $query                 = qq|SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = 'template0'|;
    my ($cluster_encoding) = $dbh->selectrow_array($query);

    if ($cluster_encoding && ($cluster_encoding =~ m/^(?:UTF-?8|UNICODE)$/i) && ($encoding !~ m/^(?:UTF-?8|UNICODE)$/i)) {
      $error = $main::locale->text('Your PostgreSQL installationen uses UTF-8 as its encoding. Therefore you have to configure Lx-Office to use UTF-8 as well.');
    }

    $dbh->disconnect();

    $main::form->error($main::locale->text('The creation of the authentication database failed:') . "\n" . $error);
  }

  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub create_tables {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my $dbh  = $self->dbconnect();

  my $charset    = $main::dbcharset;
  $charset     ||= Common::DEFAULT_CHARSET;

  $dbh->rollback();
  User->process_query($main::form, $dbh, 'sql/auth_db.sql', undef, $charset);

  $main::lxdebug->leave_sub();
}

sub save_user {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my $login  = shift;
  my %params = @_;

  my $form   = $main::form;

  my $dbh    = $self->dbconnect();

  my ($sth, $query, $user_id);

  $query     = qq|SELECT id FROM auth."user" WHERE login = ?|;
  ($user_id) = selectrow_query($form, $dbh, $query, $login);

  if (!$user_id) {
    $query     = qq|SELECT nextval('auth.user_id_seq')|;
    ($user_id) = selectrow_query($form, $dbh, $query);

    $query     = qq|INSERT INTO auth."user" (id, login) VALUES (?, ?)|;
    do_query($form, $dbh, $query, $user_id, $login);
  }

  $query = qq|DELETE FROM auth.user_config WHERE (user_id = ?)|;
  do_query($form, $dbh, $query, $user_id);

  $query = qq|INSERT INTO auth.user_config (user_id, cfg_key, cfg_value) VALUES (?, ?, ?)|;
  $sth   = prepare_query($form, $dbh, $query);

  while (my ($cfg_key, $cfg_value) = each %params) {
    next if ($cfg_key eq 'password');

    do_statement($form, $sth, $query, $user_id, $cfg_key, $cfg_value);
  }

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub can_change_password {
  my $self = shift;

  return $self->{authenticator}->can_change_password();
}

sub change_password {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my $result = $self->{authenticator}->change_password(@_);

  $main::lxdebug->leave_sub();

  return $result;
}

sub read_all_users {
  $main::lxdebug->enter_sub();

  my $self  = shift;

  my $dbh   = $self->dbconnect();
  my $query = qq|SELECT u.id, u.login, cfg.cfg_key, cfg.cfg_value
                 FROM auth.user_config cfg
                 LEFT JOIN auth."user" u ON (cfg.user_id = u.id)|;
  my $sth   = prepare_execute_query($main::form, $dbh, $query);

  my %users;

  while (my $ref = $sth->fetchrow_hashref()) {
    $users{$ref->{login}}                    ||= { 'login' => $ref->{login}, 'id' => $ref->{id} };
    $users{$ref->{login}}->{$ref->{cfg_key}}   = $ref->{cfg_value} if (($ref->{cfg_key} ne 'login') && ($ref->{cfg_key} ne 'id'));
  }

  $sth->finish();

  $main::lxdebug->leave_sub();

  return %users;
}

sub read_user {
  $main::lxdebug->enter_sub();

  my $self  = shift;
  my $login = shift;

  my $dbh   = $self->dbconnect();
  my $query = qq|SELECT u.id, u.login, cfg.cfg_key, cfg.cfg_value
                 FROM auth.user_config cfg
                 LEFT JOIN auth."user" u ON (cfg.user_id = u.id)
                 WHERE (u.login = ?)|;
  my $sth   = prepare_execute_query($main::form, $dbh, $query, $login);

  my %user_data;

  while (my $ref = $sth->fetchrow_hashref()) {
    $user_data{$ref->{cfg_key}} = $ref->{cfg_value};
    @user_data{qw(id login)}    = @{$ref}{qw(id login)};
  }

  $sth->finish();

  $main::lxdebug->leave_sub();

  return %user_data;
}

sub get_user_id {
  $main::lxdebug->enter_sub();

  my $self  = shift;
  my $login = shift;

  my $dbh   = $self->dbconnect();
  my ($id)  = selectrow_query($main::form, $dbh, qq|SELECT id FROM auth."user" WHERE login = ?|, $login);

  $main::lxdebug->leave_sub();

  return $id;
}

sub delete_user {
  $main::lxdebug->enter_sub();

  my $self  = shift;
  my $login = shift;

  my $form  = $main::form;

  my $dbh   = $self->dbconnect();
  my $query = qq|SELECT id FROM auth."user" WHERE login = ?|;

  my ($id)  = selectrow_query($form, $dbh, $query, $login);

  return $main::lxdebug->leave_sub() if (!$id);

  do_query($form, $dbh, qq|DELETE FROM auth.user_group WHERE user_id = ?|, $id);
  do_query($form, $dbh, qq|DELETE FROM auth.user_config WHERE user_id = ?|, $id);

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

# --------------------------------------

my $session_id;

sub restore_session {
  $main::lxdebug->enter_sub();

  my $self = shift;

  my $cgi            =  $main::cgi;
  $cgi             ||=  CGI->new('');

  $session_id        =  $cgi->cookie($self->get_session_cookie_name());
  $session_id        =~ s|[^0-9a-f]||g;

  $self->{SESSION}   = { };

  if (!$session_id) {
    $main::lxdebug->leave_sub();
    return SESSION_NONE;
  }

  my ($dbh, $query, $sth, $cookie, $ref, $form);

  $form   = $main::form;

  $dbh    = $self->dbconnect();
  $query  = qq|SELECT *, (mtime < (now() - '$self->{session_timeout}m'::interval)) AS is_expired FROM auth.session WHERE id = ?|;

  $cookie = selectfirst_hashref_query($form, $dbh, $query, $session_id);

  if (!$cookie || $cookie->{is_expired} || ($cookie->{ip_address} ne $ENV{REMOTE_ADDR})) {
    $self->destroy_session();
    $main::lxdebug->leave_sub();
    return SESSION_EXPIRED;
  }

  $query = qq|SELECT sess_key, sess_value FROM auth.session_content WHERE session_id = ?|;
  $sth   = prepare_execute_query($form, $dbh, $query, $session_id);

  while (my $ref = $sth->fetchrow_hashref()) {
    $self->{SESSION}->{$ref->{sess_key}} = $ref->{sess_value};
    $form->{$ref->{sess_key}}            = $ref->{sess_value} if (!defined $form->{$ref->{sess_key}});
  }

  $sth->finish();

  $main::lxdebug->leave_sub();

  return SESSION_OK;
}

sub destroy_session {
  $main::lxdebug->enter_sub();

  my $self = shift;

  if ($session_id) {
    my $dbh = $self->dbconnect();

    do_query($main::form, $dbh, qq|DELETE FROM auth.session_content WHERE session_id = ?|, $session_id);
    do_query($main::form, $dbh, qq|DELETE FROM auth.session WHERE id = ?|, $session_id);

    $dbh->commit();

    $session_id      = undef;
    $self->{SESSION} = { };
  }

  $main::lxdebug->leave_sub();
}

sub expire_sessions {
  $main::lxdebug->enter_sub();

  my $self  = shift;

  my $dbh   = $self->dbconnect();
  my $query =
    qq|DELETE FROM auth.session_content
       WHERE session_id IN
         (SELECT id
          FROM auth.session
          WHERE (mtime < (now() - '$self->{session_timeout}m'::interval)))|;

  do_query($main::form, $dbh, $query);

  $query =
    qq|DELETE FROM auth.session
       WHERE (mtime < (now() - '$self->{session_timeout}m'::interval))|;

  do_query($main::form, $dbh, $query);

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub _create_session_id {
  $main::lxdebug->enter_sub();

  my @secs = gettimeofday();
  srand $secs[1] + $$;

  my @data;
  map { push @data, int(rand() * 255); } (1..32);

  my $id = md5_hex(pack 'C*', @data);

  $main::lxdebug->leave_sub();

  return $id;
}

sub create_or_refresh_session {
  $main::lxdebug->enter_sub();

  my $self = shift;

  $session_id ||= $self->_create_session_id();

  my ($form, $dbh, $query, $sth, $id);

  $form  = $main::form;
  $dbh   = $self->dbconnect();

  $query = qq|SELECT id FROM auth.session WHERE id = ?|;

  ($id)  = selectrow_query($form, $dbh, $query, $session_id);

  if ($id) {
    do_query($form, $dbh, qq|UPDATE auth.session SET mtime = now() WHERE id = ?|, $session_id);
    do_query($form, $dbh, qq|DELETE FROM auth.session_content WHERE session_id = ?|, $session_id);

  } else {
    do_query($form, $dbh, qq|INSERT INTO auth.session (id, ip_address, mtime) VALUES (?, ?, now())|, $session_id, $ENV{REMOTE_ADDR});

  }

  $query = qq|INSERT INTO auth.session_content (session_id, sess_key, sess_value) VALUES (?, ?, ?)|;
  $sth   = prepare_query($form, $dbh, $query);

  foreach my $key (sort keys %{ $self->{SESSION} }) {
    do_statement($form, $sth, $query, $session_id, $key, $self->{SESSION}->{$key});
  }

  $sth->finish();
  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub set_session_value {
  $main::lxdebug->enter_sub();

  my $self  = shift;

  $self->{SESSION} ||= { };

  while (2 <= scalar @_) {
    my $key   = shift;
    my $value = shift;

    $self->{SESSION}->{$key} = $value;
  }

  $main::lxdebug->leave_sub();
}

sub set_cookie_environment_variable {
  my $self = shift;
  $ENV{HTTP_COOKIE} = $self->get_session_cookie_name() . "=${session_id}";
}

sub get_session_cookie_name {
  my $self = shift;

  return $self->{cookie_name} || 'lx_office_erp_session_id';
}

sub get_session_id {
  return $session_id;
}

sub session_tables_present {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my $dbh  = $self->dbconnect(1);

  if (!$dbh) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  my $query =
    qq|SELECT COUNT(*)
       FROM pg_tables
       WHERE (schemaname = 'auth')
         AND (tablename IN ('session', 'session_content'))|;

  my ($count) = selectrow_query($main::form, $dbh, $query);

  $main::lxdebug->leave_sub();

  return 2 == $count;
}

# --------------------------------------

sub all_rights_full {
  my $locale = $main::locale;

  my @all_rights = (
    ["--crm",                          $locale->text("CRM optional software")],
    ["crm_search",                     $locale->text("CRM search")],
    ["crm_new",                        $locale->text("CRM create customers, vendors and contacts")],
    ["crm_service",                    $locale->text("CRM services")],
    ["crm_admin",                      $locale->text("CRM admin")],
    ["crm_adminuser",                  $locale->text("CRM user")],
    ["crm_adminstatus",                $locale->text("CRM status")],
    ["crm_email",                      $locale->text("CRM send email")],
    ["crm_termin",                     $locale->text("CRM termin")],
    ["crm_opportunity",                $locale->text("CRM opportunity")],
    ["crm_knowhow",                    $locale->text("CRM know how")],
    ["crm_follow",                     $locale->text("CRM follow up")],
    ["crm_notices",                    $locale->text("CRM notices")],
    ["crm_other",                      $locale->text("CRM other")],
    ["--master_data",                  $locale->text("Master Data")],
    ["customer_vendor_edit",           $locale->text("Create and edit customers and vendors")],
    ["part_service_assembly_edit",     $locale->text("Create and edit parts, services, assemblies")],
    ["project_edit",                   $locale->text("Create and edit projects")],
    ["license_edit",                   $locale->text("Manage license keys")],
    ["--ar",                           $locale->text("AR")],
    ["sales_quotation_edit",           $locale->text("Create and edit sales quotations")],
    ["sales_order_edit",               $locale->text("Create and edit sales orders")],
    ["sales_delivery_order_edit",      $locale->text("Create and edit sales delivery orders")],
    ["invoice_edit",                   $locale->text("Create and edit invoices and credit notes")],
    ["dunning_edit",                   $locale->text("Create and edit dunnings")],
    ["--ap",                           $locale->text("AP")],
    ["request_quotation_edit",         $locale->text("Create and edit RFQs")],
    ["purchase_order_edit",            $locale->text("Create and edit purchase orders")],
    ["purchase_delivery_order_edit",   $locale->text("Create and edit purchase delivery orders")],
    ["vendor_invoice_edit",            $locale->text("Create and edit vendor invoices")],
    ["--warehouse_management",         $locale->text("Warehouse management")],
    ["warehouse_contents",             $locale->text("View warehouse content")],
    ["warehouse_management",           $locale->text("Warehouse management")],
    ["--general_ledger_cash",          $locale->text("General ledger and cash")],
    ["general_ledger",                 $locale->text("Transactions, AR transactions, AP transactions")],
    ["datev_export",                   $locale->text("DATEV Export")],
    ["cash",                           $locale->text("Receipt, payment, reconciliation")],
    ["--reports",                      $locale->text('Reports')],
    ["report",                         $locale->text('All reports')],
    ["advance_turnover_tax_return",    $locale->text('Advance turnover tax return')],
    ["--others",                       $locale->text("Others")],
    ["email_bcc",                      $locale->text("May set the BCC field when sending emails")],
    ["config",                         $locale->text("Change Lx-Office installation settings (all menu entries beneath 'System')")],
    );

  return @all_rights;
}

sub all_rights {
  return grep !/^--/, map { $_->[0] } all_rights_full();
}

sub read_groups {
  $main::lxdebug->enter_sub();

  my $self = shift;

  my $form   = $main::form;
  my $groups = {};
  my $dbh    = $self->dbconnect();

  my $query  = 'SELECT * FROM auth."group"';
  my $sth    = prepare_execute_query($form, $dbh, $query);

  my ($row, $group);

  while ($row = $sth->fetchrow_hashref()) {
    $groups->{$row->{id}} = $row;
  }
  $sth->finish();

  $query = 'SELECT * FROM auth.user_group WHERE group_id = ?';
  $sth   = prepare_query($form, $dbh, $query);

  foreach $group (values %{$groups}) {
    my @members;

    do_statement($form, $sth, $query, $group->{id});

    while ($row = $sth->fetchrow_hashref()) {
      push @members, $row->{user_id};
    }
    $group->{members} = [ uniq @members ];
  }
  $sth->finish();

  $query = 'SELECT * FROM auth.group_rights WHERE group_id = ?';
  $sth   = prepare_query($form, $dbh, $query);

  foreach $group (values %{$groups}) {
    $group->{rights} = {};

    do_statement($form, $sth, $query, $group->{id});

    while ($row = $sth->fetchrow_hashref()) {
      $group->{rights}->{$row->{right}} |= $row->{granted};
    }

    map { $group->{rights}->{$_} = 0 if (!defined $group->{rights}->{$_}); } all_rights();
  }
  $sth->finish();

  $main::lxdebug->leave_sub();

  return $groups;
}

sub save_group {
  $main::lxdebug->enter_sub();

  my $self  = shift;
  my $group = shift;

  my $form  = $main::form;
  my $dbh   = $self->dbconnect();

  my ($query, $sth, $row, $rights);

  if (!$group->{id}) {
    ($group->{id}) = selectrow_query($form, $dbh, qq|SELECT nextval('auth.group_id_seq')|);

    $query = qq|INSERT INTO auth."group" (id, name, description) VALUES (?, '', '')|;
    do_query($form, $dbh, $query, $group->{id});
  }

  do_query($form, $dbh, qq|UPDATE auth."group" SET name = ?, description = ? WHERE id = ?|, map { $group->{$_} } qw(name description id));

  do_query($form, $dbh, qq|DELETE FROM auth.user_group WHERE group_id = ?|, $group->{id});

  $query  = qq|INSERT INTO auth.user_group (user_id, group_id) VALUES (?, ?)|;
  $sth    = prepare_query($form, $dbh, $query);

  foreach my $user_id (uniq @{ $group->{members} }) {
    do_statement($form, $sth, $query, $user_id, $group->{id});
  }
  $sth->finish();

  do_query($form, $dbh, qq|DELETE FROM auth.group_rights WHERE group_id = ?|, $group->{id});

  $query = qq|INSERT INTO auth.group_rights (group_id, "right", granted) VALUES (?, ?, ?)|;
  $sth   = prepare_query($form, $dbh, $query);

  foreach my $right (keys %{ $group->{rights} }) {
    do_statement($form, $sth, $query, $group->{id}, $right, $group->{rights}->{$right} ? 't' : 'f');
  }
  $sth->finish();

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub delete_group {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my $id   = shift;

  my $form = $main::from;

  my $dbh  = $self->dbconnect();

  do_query($form, $dbh, qq|DELETE FROM auth.user_group WHERE group_id = ?|, $id);
  do_query($form, $dbh, qq|DELETE FROM auth.group_rights WHERE group_id = ?|, $id);
  do_query($form, $dbh, qq|DELETE FROM auth."group" WHERE id = ?|, $id);

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub evaluate_rights_ary {
  $main::lxdebug->enter_sub(2);

  my $ary    = shift;

  my $value  = 0;
  my $action = '|';

  foreach my $el (@{$ary}) {
    if (ref $el eq "ARRAY") {
      if ($action eq '|') {
        $value |= evaluate_rights_ary($el);
      } else {
        $value &= evaluate_rights_ary($el);
      }

    } elsif (($el eq '&') || ($el eq '|')) {
      $action = $el;

    } elsif ($action eq '|') {
      $value |= $el;

    } else {
      $value &= $el;

    }
  }

  $main::lxdebug->enter_sub(2);

  return $value;
}

sub _parse_rights_string {
  $main::lxdebug->enter_sub(2);

  my $self   = shift;

  my $login  = shift;
  my $access = shift;

  my @stack;
  my $cur_ary = [];

  push @stack, $cur_ary;

  while ($access =~ m/^([a-z_0-9]+|\||\&|\(|\)|\s+)/) {
    my $token = $1;
    substr($access, 0, length $1) = "";

    next if ($token =~ /\s/);

    if ($token eq "(") {
      my $new_cur_ary = [];
      push @stack, $new_cur_ary;
      push @{$cur_ary}, $new_cur_ary;
      $cur_ary = $new_cur_ary;

    } elsif ($token eq ")") {
      pop @stack;

      if (!@stack) {
        $main::lxdebug->enter_sub(2);
        return 0;
      }

      $cur_ary = $stack[-1];

    } elsif (($token eq "|") || ($token eq "&")) {
      push @{$cur_ary}, $token;

    } else {
      push @{$cur_ary}, $self->{RIGHTS}->{$login}->{$token} * 1;
    }
  }

  my $result = ($access || (1 < scalar @stack)) ? 0 : evaluate_rights_ary($stack[0]);

  $main::lxdebug->enter_sub(2);

  return $result;
}

sub check_right {
  $main::lxdebug->enter_sub(2);

  my $self    = shift;
  my $login   = shift;
  my $right   = shift;
  my $default = shift;

  $self->{FULL_RIGHTS}           ||= { };
  $self->{FULL_RIGHTS}->{$login} ||= { };

  if (!defined $self->{FULL_RIGHTS}->{$login}->{$right}) {
    $self->{RIGHTS}           ||= { };
    $self->{RIGHTS}->{$login} ||= $self->load_rights_for_user($login);

    $self->{FULL_RIGHTS}->{$login}->{$right} = $self->_parse_rights_string($login, $right);
  }

  my $granted = $self->{FULL_RIGHTS}->{$login}->{$right};
  $granted    = $default if (!defined $granted);

  $main::lxdebug->leave_sub(2);

  return $granted;
}

sub assert {
  $main::lxdebug->enter_sub(2);

  my $self       = shift;
  my $right      = shift;
  my $dont_abort = shift;

  my $form       = $main::form;

  if ($self->check_right($form->{login}, $right)) {
    $main::lxdebug->leave_sub(2);
    return 1;
  }

  if (!$dont_abort) {
    delete $form->{title};
    $form->show_generic_error($main::locale->text("You do not have the permissions to access this function."));
  }

  $main::lxdebug->leave_sub(2);

  return 0;
}

sub load_rights_for_user {
  $main::lxdebug->enter_sub();

  my $self  = shift;
  my $login = shift;

  my $form  = $main::form;
  my $dbh   = $self->dbconnect();

  my ($query, $sth, $row, $rights);

  $rights = {};

  $query =
    qq|SELECT gr."right", gr.granted
       FROM auth.group_rights gr
       WHERE group_id IN
         (SELECT ug.group_id
          FROM auth.user_group ug
          LEFT JOIN auth."user" u ON (ug.user_id = u.id)
          WHERE u.login = ?)|;

  $sth = prepare_execute_query($form, $dbh, $query, $login);

  while ($row = $sth->fetchrow_hashref()) {
    $rights->{$row->{right}} |= $row->{granted};
  }
  $sth->finish();

  map({ $rights->{$_} = 0 unless (defined $rights->{$_}); } SL::Auth::all_rights());

  $main::lxdebug->leave_sub();

  return $rights;
}

1;
