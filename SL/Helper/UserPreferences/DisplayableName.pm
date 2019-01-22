package SL::Helper::UserPreferences::DisplayableName;

use strict;
use parent qw(Rose::Object);

use Carp;
use List::MoreUtils qw(none);

use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(module default_prefs user_prefs data) ],
);

sub get {
  $_[0]->data;
}

sub _store {
  my ($self, $val, $target) = @_;

  return if $self->data eq $val;

  $self->data($val);
  $self->$target->store($self->module, $self->data);
}

sub init_default_prefs {
  SL::Helper::UserPreferences->new(
    login           => $_[0]->default_login,
    namespace       => $_[0]->namespace,
  )
}

sub init_user_prefs {
  SL::Helper::UserPreferences->new(
    namespace => $_[0]->namespace,
  )
}

sub init_data {
  my $data;
  $data   = $_[0]->user_prefs   ->get($_[0]->module);
  $data //= $_[0]->default_prefs->get($_[0]->module);

  return $data;
}

sub init_module {
  die 'need module';
}

# proxy to user prefs
sub delete        { $_[0]->user_prefs->delete($_[0]->module); $_[0]->data($_[0]->init_data()) }
sub login         { $_[0]->user_prefs->login }

# proxy to default prefs
sub get_default   { $_[0]->default_prefs->get($_[0]->module) }

# aliases
sub store_value   { _store(@_, 'user_prefs')    }
sub store_default { _store(@_, 'default_prefs') }

# read only stuff
sub default_login { '#default#' }
sub namespace     { 'DisplayableName' }
sub version       { 1 }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences::DisplayableName - hybrid preferences intended
for two tiered (user over default) displayable name preferences

=head1 SYNOPSIS

  use SL::Helper::UserPreferences::DisplayableName;
  my $prefs = SL::Helper::UserPreferences::DisplayableName->new(
    module => 'SL::DB::Customer'
  );

  my $value = $prefs->get;
  my $value = $prefs->store_value('<%number%> <%name%> (PLZ <%zipcode%>)');
  my $value = $prefs->store_default('<%number%> <%name%>');

=head1 DESCRIPTION

This module proxies two L<SL::Helper::UserPreferences> instances, one global and
one for the current user.
It is intended to be used with the C<SL::DB::SomeObject> classes via
L<SL::DB::Helper::DisplayableNamePreferences> (see there).

=head1 BUGS

None yet :)

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
