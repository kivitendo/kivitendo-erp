package SL::Helper::UserPreferences::ItemInputPosition;

use strict;
use parent qw(Rose::Object);

use Carp;
use List::MoreUtils qw(none);

use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(user_prefs) ],
);

sub get_order_item_input_position {
  $_[0]->user_prefs->get('order_item_input_position')
}

sub store_order_item_input_position {
  my ($self, $value) = @_;

  if ($value eq 'default') {
    $self->user_prefs->delete('order_item_input_position');
  } else {
    $self->user_prefs->store('order_item_input_position', $value);
  }
}

sub init_user_prefs {
  SL::Helper::UserPreferences->new(
    namespace => $_[0]->namespace,
  )
}

# read only stuff
sub namespace     { 'ItemInputPosition' }
sub version       { 1 }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences::ItemInputPosition - preferences intended
to store user settings for the behavior of the item input in record masks

=head1 SYNOPSIS

  use SL::Helper::UserPreferences::ItemInputPosition;
  my $prefs = SL::Helper::UserPreferences::ItemInputPosition->new();

  $prefs->store_order_item_input_position(1);
  my $value = $prefs->get_order_item_input_position;

=head1 DESCRIPTION

Currently this only applies to the item input in L<SL::Controller::Order> forms.

Readable values:

=over 4

=item * undefined - use client setting

=item * 0 - render above the positions

=item * 1 - render below the positions

=back

For storage C<default> is used to delete the value since form values can not be undefined.

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@googlemail.comE<gt>

=cut
