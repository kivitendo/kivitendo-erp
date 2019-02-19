package SL::Helper::UserPreferences;

use strict;
use parent qw(Rose::Object);
use version;

use SL::DBUtils qw(selectall_hashref_query selectfirst_hashref_query do_query selectcol_array_query);
use SL::DB;

use Rose::Object::MakeMethods::Generic (
 'scalar --get_set_init' => [ qw(login namespace upgrade_callbacks current_version auto_store_back) ],
);

sub store {
  my ($self, $key, $value) = @_;

  SL::DB->client->with_transaction(sub {
    my $tuple = $self->get_tuple($key);

    if ($tuple && $tuple->{id}) {
      $tuple->{value}  = $value;
      $self->_update($tuple);
    } else {
      my $query = 'INSERT INTO user_preferences (login, namespace, version, key, value) VALUES (?, ?, ?, ?, ?)';
      do_query($::form, $::form->get_standard_dbh, $query, $self->login, $self->namespace, $self->current_version, $key, $value);
    }
    1;
  }) or do { die SL::DB->client->error };
}

sub get {
  my ($self, $key) = @_;

  my $tuple = $self->get_tuple($key);

  $tuple ? $tuple->{value} : undef;
}

sub get_tuple {
  my ($self, $key) = @_;

  my $tuple;

  SL::DB->client->with_transaction(sub {
    $tuple = selectfirst_hashref_query($::form, $::form->get_standard_dbh, <<"", $self->login, $self->namespace, $key);
      SELECT * FROM user_preferences WHERE login = ? AND namespace = ? AND key = ?

    if ($tuple && $tuple->{version} < $self->current_version) {
      $self->_upgrade($tuple);
    }

    if ($tuple && $tuple->{version} > $self->current_version) {
      die "Future version $tuple->{version} for user preference @{ $self->namespace }/$key. Expected @{ $self->current_version } or less.";
    }
    1;
  }) or do { die SL::DB->client->error };

  return $tuple;
}

sub get_all {
  my ($self) = @_;

  my $data;

  SL::DB->client->with_transaction(sub {
    $data = selectall_hashref_query($::form, $::form->get_standard_dbh, <<"", $self->login, $self->namespace);
      SELECT * FROM user_preferences WHERE login = ? AND namespace = ?

    for my $tuple (@$data) {
      if ($tuple->{version} < $self->current_version) {
        $self->_upgrade($tuple);
      }

      if ($tuple->{version} > $self->current_version) {
        die "Future version $tuple->{version} for user preference @{ $self->namespace }/$tuple->{key}. Expected @{ $self->current_version } or less.";
      }
    }
    1;
  }) or do { die SL::DB->client->error };

  return $data;
}

sub get_keys {
  my ($self) = @_;

  my @keys = selectcol_array_query($::form, SL::DB->client->dbh, <<"", $self->login, $self->namespace);
    SELECT key FROM user_preferences WHERE login = ? AND namespace = ?

  return @keys;
}

sub delete {
  my ($self, $key) = @_;

  die 'delete without  key is not allowed, use delete_all instead' unless $key;

  SL::DB->client->with_transaction(sub {
    my $query =  'DELETE FROM user_preferences WHERE login = ? AND namespace = ? AND key = ?';
    do_query($::form, $::form->get_standard_dbh, $query, $self->login, $self->namespace, $key);
    1;
  }) or do { die SL::DB->client->error };
}

sub delete_all {
  my ($self, $key) = @_;

  my @keys;

  SL::DB->client->with_transaction(sub {
    my $query = 'DELETE FROM user_preferences WHERE login = ? AND namespace = ?';
    do_query($::form, $::form->get_standard_dbh, $query, $self->login, $self->namespace);
    1;
  }) or do { die SL::DB->client->error };
}

### internal stuff

sub _upgrade {
  my ($self, $tuple) = @_;

  for my $to_version (sort { $a <=> $b } grep { $_ > $tuple->{version} } keys %{ $self->upgrade_callbacks }) {
    $tuple->{value}   = $self->upgrade_callbacks->{$to_version}->($tuple->{value});
    $tuple->{version} = $to_version;
  }

  if ($self->auto_store_back) {
    $self->_update($tuple);
  }
}

sub _update {
  my ($self, $tuple) = @_;

  my $query = 'UPDATE user_preferences SET version = ?, value = ? WHERE id = ?';
  do_query($::form, $::form->get_standard_dbh, $query, $tuple->{version}, $tuple->{value}, $tuple->{id});
}

### defaults stuff

sub init_login             { SL::DB::Manager::Employee->current->login    }
sub init_namespace         { ref $_[0]                                    }
sub init_upgrade_callbacks { +{}                                          }
sub init_current_version   { version->parse((ref $_[0])->VERSION)->numify }
sub init_auto_store_back   { 1                                            }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences - user based preferences store

=head1 SYNOPSIS

  use SL::Helper::UserPreferences;
  my $user_pref = SL::Helper::UserPreferences->new(
    login             => $login,        # defaults to current user
    namespace         => $namespace,    # defaults to current package
    upgrade_callbacks => $upgrade_callbacks,
    current_version   => $version,      # defaults to __PACKAGE__->VERSION->numify
    auto_store_back   => 0,             # default 1
  );

  $user_pref->store($key, $value);
  my $val    = $user_pref->get($key);
  my $tuple  = $user_pref->get_tuple($key);
  my $tuples = $user_pref->get_all;
  my $keys   = $user_pref->get_keys;
  $user_pref->delete($key);
  $user_pref->delete_all;

=head1 DESCRIPTION

This module provides a generic storage for information that needs to be stored
between sessions per user and per client and between versions of the program.

The storage can be accessed as a generic key/value dictionary, but also
requires a namespace to avoid clashes and a version of the information.
Additionally you must provide means to upgrade or invalidate stored information
that is out of date, i.e. after a program upgrade.

=head1 FUNCTIONS

=over 4

=item C<new PARAMS>

Creates a new instance. Available C<PARAMS>:

=over 4

=item C<login>

The user for this storage. Defaults to current user login.

=item C<namespace>

A unique namespace. Defaults to the calling package.

=item C<upgrade_callbacks>

A hashref with version numbers as keys and subs as values. These subs are
expected to take a value and return an upgraded value for the version of their
key.

No default. Mandatory.

=item C<current_version>

The version object that is considered current for stored information. Defaults
to the version of the calling package. MUST be a number, and not a version
object, so that versions can be used as hash keys in the ugrade_callbacks.

=item C<auto_store_back>

An otional flag indicating whether values from the database that were upgraded to a
newer version should be stored back automatically. Defaults to
C<$::lx_office_conf{debug}{auto_store_back_upgraded_user_preferences}> which in
turn defaults to true.

=back

=item C<store KEY VALUE>

Stores a key-value tuple. If there exists already a value for this key, it will
be overwritten.

=item C<get KEY>

Retrieves a value.

Returns the value. If no such value exists returns undef instead.

This is for easy of use, and does no distinction between non-existing values
and valid undefined values. Use C<get_tuple> if you need this.

=item C<get_tuple KEY>

Retrieves a key-value tuple.

Returns a hashref with C<key> and C<value> entries. If no such value
exists returns undef instead.

=item C<get_all>

Retrieve all key-value tuples in this namespace and user.

Returns an arrayref of hashrefs.

=item C<get_keys>

Retrieve all keys for this namespace. Note: Unless you store vast amount of
data, it's most likely easier to just C<get_all>.

Returns an arrayref of keys.

=item C<delete KEY>

Deletes a tuple.

=item C<delete_all>

Delete all tuples for this namespace and user.

=back

=head1 VERSIONING

Every entry in the user prefs must have a version to be compatible in case of
code upgrades.

Code reading user prefs must check if the version is the expected one, and must
have upgrade code to upgrade out of date preferences to the current version.

Code SHOULD write the upgraded version back to the store at the earliest time
to keep preferences up to date. This should be able to be disabled to have
developer versions not overwrite preferences with unsupported versions.

Example:

Initial code dealing with prefs:

  our $VERSION = v1;

  $user_prefs->store("selected tab", $::form->{selected_tab});

And the someone edits the code and removes the tab "Webdav". To ensure
favorites with webdav selected are upgraded:

  our $VERSION = v2;

  my $upgrade_callbacks = {
    2 => sub { $_[0] eq 'WebDav' ? 'MasterData' : $_[0]; },
  };

  my $val = $user_prefs->get("selected tab");

=head1 LACK OF TYPING

This controller will not attempt to preserve types. All data will be
stringified. If your code needs to preserve numbers, you MUST encode the data
to JSON or YAML before storing.

=head1 PLANNED BEST PRACTICE

To be able to decouple controllers and the schema upgrading required for this,
there should be exactly one module responsible for managing user preferences for
each namespace. You should find the corresponding preferences owners in the
class namespace C<SL::Helper::UserPreferences>.

For example the namespace C<PartsSearchFavorites> should only be managed by
C<SL::Helper::UserPreferences::PartsSearchFavorites>. This way, it's possible
to keep the upgrades in one place, and to migrate upgrades out of there into
database upgrades during major releases. They also don't clutter up
controllers.

It is planned to strip all modules located there of their upgrade for a release
and do automatic database upgrades.

To avoid version clashes when developing customer branches, please only use
stable version bumps in the unstable branch, and use dev versions in customer
branches.

=head1 BEHAVIOUR

=over 4

=item *

If a (namepace, key) tuple exists, a store will overwrite the last version

=item *

If the value retrieved from the database is newer than the code version, an
error must be thrown.

=item *

get will check the version against the current version and apply all upgrade
steps.

=item *

If the final step is not the current version, behaviour is undefined

=item *

get_all will always return scalar context.

=back

=head1 TODO AND SPECIAL CASES

* not defined whether it should be possible to retrieve the version of a tuple

* it's not specified how to return invalidation from upgrade, nor how to handle
  that

* it's not specified whether admin is a user. for now it dies.

* We're missing user agnostic methods for database upgrades

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>

=cut
