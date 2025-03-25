# @tag: clients
# @description: Einführung von Mandanten
# @depends: release_3_0_0
# @ignore: 0
package SL::DBUpgrade2::Auth::clients;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use List::MoreUtils qw(any all);
use List::Util qw(first);

use SL::DBConnect;
use SL::DBUtils;
use SL::Template;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(clients) ],
  'scalar --get_set_init' => [ qw(users groups templates auth_db_settings data_dbhs) ],
);

sub init_users {
  my ($self) = @_;
  my @users  = selectall_hashref_query($::form, $self->dbh, qq|SELECT * FROM auth."user" ORDER BY lower(login)|);

  foreach my $user (@users) {
    my @attributes = selectall_hashref_query($::form, $self->dbh, <<SQL, $user->{id});
     SELECT cfg_key, cfg_value
     FROM auth.user_config
     WHERE user_id = ?
SQL

    $user->{ $_->{cfg_key} } = $_->{cfg_value} for @attributes;
  }

  return \@users;
}

sub init_groups {
  my ($self) = @_;
  return [ selectall_hashref_query($::form, $self->dbh, qq|SELECT * FROM auth."group" ORDER BY lower(name)|) ];
}

sub init_templates {
  my %templates = SL::Template->available_templates;
  return $templates{print_templates};
}

sub init_auth_db_settings {
  my $cfg = $::lx_office_conf{'authentication/database'};
  return {
    dbhost => $cfg->{host} || 'localhost',
    dbport => $cfg->{port} || 5432,
    dbname => $cfg->{name},
  };
}

sub init_data_dbhs {
  return [];
}

sub _clear_field {
  my ($text) = @_;

  $text ||= '';
  $text   =~ s/^\s+|\s+$//g;

  return $text;
}

sub _group_into_clients {
  my ($self) = @_;

  my @match_fields = qw(dbhost dbport dbname);
  my @copy_fields  = (@match_fields, qw(address company co_ustid dbuser dbpasswd duns sepa_creditor_id taxnumber templates));
  my @clients;

  # Group users into clients. Users which have identical database
  # settings (host, port and name) will be grouped. The other fields
  # like tax number etc. are taken from the first user and only filled
  # from user users if they're still unset.
  foreach my $user (@{ $self->users }) {
    $user->{$_} = _clear_field($user->{$_}) for @copy_fields;

    my $existing_client = first { my $client = $_; all { ($user->{$_} || '') eq ($client->{$_} || '') } @match_fields } @clients;

    if ($existing_client) {
      push @{ $existing_client->{users} }, $user->{id};
      $existing_client->{$_} ||= $user->{$_} for @copy_fields;
      next;
    }

    push @clients, {
      map({ $_ => $user->{$_} } @copy_fields),
      users   => [ $user->{id} ],
      groups  => [ map { $_->{id} } @{ $self->groups } ],
      enabled => 1,
    };
  }

  # Ignore users (and therefore clients) for which no database
  # configuration has been given.
  @clients = grep { my $client = $_; any { $client->{$_} } @match_fields } @clients;

  # If there's only one client set that one as default.
  $clients[0]->{is_default} = 1 if scalar(@clients) == 1;

  # Set a couple of defaults for database fields.
  my $num = 0;
  foreach my $client (@clients) {
    $num                += 1;
    $client->{name}    ||= $::locale->text('Client #1', $num);
    $client->{dbhost}  ||= 'localhost';
    $client->{dbport}  ||= 5432;
    $client->{templates} =~ s:templates/::;
  }

  $self->clients(\@clients);
}

sub _analyze {
  my ($self, %params) = @_;

  $self->_group_into_clients;

  return $self->_do_convert if !@{ $self->clients };

  print $::form->parse_html_template('dbupgrade/auth/clients', { SELF => $self });

  return 2;
}

sub _verify_clients {
  my ($self) = @_;

  my (%names, @errors);

  my $num = 0;
  foreach my $client (@{ $self->clients }) {
    $num += 1;

    next if !$client->{enabled};

    $client->{$_} = _clear_field($client->{$_}) for qw(address co_ustid company dbhost dbname dbpasswd dbport dbuser duns sepa_creditor_id taxnumber templates);

    if (!$client->{name} || $names{ $client->{name} }) {
      push @errors, $::locale->text('New client #1: The name must be unique and not empty.', $num);
    }

    $names{ $client->{name} } = 1;

    if (any { !$client->{$_} } qw(dbhost dbport dbname dbuser)) {
      push @errors, $::locale->text('New client #1: The database configuration fields "host", "port", "name" and "user" must not be empty.', $num);
    }
  }

  return @errors;
}

sub _alter_auth_database_structure {
  my ($self) = @_;

  my @queries = (
    qq|CREATE TABLE auth.clients (
         id         SERIAL  PRIMARY KEY,
         name       TEXT    NOT NULL UNIQUE,
         dbhost     TEXT    NOT NULL,
         dbport     INTEGER NOT NULL DEFAULT 5432,
         dbname     TEXT    NOT NULL,
         dbuser     TEXT    NOT NULL,
         dbpasswd   TEXT    NOT NULL,
         is_default BOOLEAN NOT NULL DEFAULT FALSE,

         UNIQUE (dbhost, dbport, dbname)
       )|,
    qq|CREATE TABLE auth.clients_users (
         client_id INTEGER NOT NULL REFERENCES auth.clients (id),
         user_id   INTEGER NOT NULL REFERENCES auth."user"  (id),

         PRIMARY KEY (client_id, user_id)
       )|,
    qq|CREATE TABLE auth.clients_groups (
         client_id INTEGER NOT NULL REFERENCES auth.clients (id),
         group_id  INTEGER NOT NULL REFERENCES auth."group" (id),

         PRIMARY KEY (client_id, group_id)
       )|,
  );

  $self->db_query($_, may_fail => 0) for @queries;
}

sub _alter_data_database_structure {
  my ($self, $dbh) = @_;

  my @queries = (
    qq|ALTER TABLE defaults ADD COLUMN company          TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN address          TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN taxnumber        TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN co_ustid         TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN duns             TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN sepa_creditor_id TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN templates        TEXT|,
    qq|INSERT INTO schema_info (tag, login) VALUES ('clients', 'admin')|,
  );

  foreach my $query (@queries) {
    $dbh->do($query) || die $self->db_errstr($dbh);
  }
}

sub _create_clients_in_auth_database {
  my ($self)  = @_;

  my @client_columns   = qw(name dbhost dbport dbname dbuser dbpasswd is_default);
  my $q_client         = qq|INSERT INTO auth.clients (| . join(', ', @client_columns) . qq|) VALUES (| . join(', ', ('?') x @client_columns) . qq|) RETURNING id|;
  my $sth_client       = $self->dbh->prepare($q_client) || die $self->db_errstr;

  my $q_client_user    = qq|INSERT INTO auth.clients_users (client_id, user_id) VALUES (?, ?)|;
  my $sth_client_user  = $self->dbh->prepare($q_client_user) || die $self->db_errstr;

  my $q_client_group   = qq|INSERT INTO auth.clients_groups (client_id, group_id) VALUES (?, ?)|;
  my $sth_client_group = $self->dbh->prepare($q_client_group) || die $self->db_errstr;

  foreach my $client (@{ $self->clients }) {
    next unless $client->{enabled};

    $client->{is_default} = $client->{is_default} ? 1 : 0;

    $sth_client->execute(@{ $client }{ @client_columns }) || die;
    my $client_id = $sth_client->fetch->[0];

    $sth_client_user ->execute($client_id, $_) || die for @{ $client->{users}  || [] };
    $sth_client_group->execute($client_id, $_) || die for @{ $client->{groups} || [] };
  }

  $sth_client      ->finish;
  $sth_client_user ->finish;
  $sth_client_group->finish;
}

sub _clean_auth_database {
  my ($self) = @_;

  my @keys_to_delete = qw(acs address admin anfragen angebote bestellungen businessnumber charset companies company co_ustid currency dbconnect dbdriver dbhost dbname dboptions dbpasswd dbport dbuser duns
                          einkaufsrechnungen in_numberformat lieferantenbestellungen login pdonumber printer rechnungen role sdonumber sepa_creditor_id sid steuernummer taxnumber templates);

  $self->dbh->do(qq|DELETE FROM auth.user_config WHERE cfg_key IN (| . join(', ', ('?') x @keys_to_delete) . qq|)|, undef, @keys_to_delete)
    || die $self->db_errstr;
}

sub _copy_fields_to_data_database {
  my ($self, $client) = @_;

  my $dbh = SL::DBConnect->connect('dbi:Pg:dbname=' . $client->{dbname} . ';host=' . $client->{dbhost} . ';port=' . $client->{dbport},
                                   $client->{dbuser}, $client->{dbpasswd},
                                   SL::DBConnect->get_options(AutoCommit => 0));
  if (!$dbh) {
    die join("\n",
             $::locale->text('The connection to the configured client database "#1" on host "#2:#3" failed.', $client->{dbname}, $client->{dbhost}, $client->{dbport}),
             $::locale->text('Please correct the settings and try again or deactivate that client.'),
             $::locale->text('Error message from the database: #1', $self->db_errstr('DBI')));
  }

  my ($has_been_applied) = $dbh->selectrow_array(qq|SELECT tag FROM schema_info WHERE tag = 'clients'|);

  if (!$has_been_applied) {
    $self->_alter_data_database_structure($dbh);
  }

  my @columns = qw(company address taxnumber co_ustid duns sepa_creditor_id templates);
  my $query   = join ', ', map { "$_ = ?" } @columns;
  my @values  = @{ $client }{ @columns };

  if (!$dbh->do(qq|UPDATE defaults SET $query|, undef, @values)) {
    die join("\n",
             $::locale->text('Updating the client fields in the database "#1" on host "#2:#3" failed.', $client->{dbname}, $client->{dbhost}, $client->{dbport}),
             $::locale->text('Please correct the settings and try again or deactivate that client.'),
             $::locale->text('Error message from the database: #1', $self->db_errstr('DBI')));
  }

  $self->data_dbhs([ @{ $self->data_dbhs }, $dbh ]);
}

sub _commit_data_database_changes {
  my ($self) = @_;

  foreach my $dbh (@{ $self->data_dbhs }) {
    $dbh->commit;
    $dbh->disconnect;
  }
}

sub _do_convert {
  my ($self) = @_;

  # Skip clients that are not enabled. Clean fields.
  my $num = 0;
  foreach my $client (@{ $self->clients }) {
    $num += 1;

    next if !$client->{enabled};

    $client->{$_}        = _clear_field($client->{$_}) for qw(dbhost dbport dbname dbuser dbpasswd address company co_ustid dbuser dbpasswd duns sepa_creditor_id taxnumber templates);
    $client->{templates} = 'templates/' . $client->{templates};
  }

  $self->_copy_fields_to_data_database($_) for grep { $_->{enabled} } @{ $self->clients };

  $self->_alter_auth_database_structure;
  $self->_create_clients_in_auth_database;
  $self->_clean_auth_database;

  $self->_commit_data_database_changes;

  return 1;
}

sub run {
  my ($self) = @_;

  return $self->_analyze if !$::form->{clients} || !@{ $::form->{clients} };

  $self->clients($::form->{clients});

  my @errors = $self->_verify_clients;

  return $self->_do_convert if !@errors;

  flash('error', $_) for @errors;

  print $::form->parse_html_template('dbupgrade/auth/clients', { SELF => $self });

  return 1;
}

1;
