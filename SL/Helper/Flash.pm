package SL::Helper::Flash;

use strict;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw(flash flash_later);
our @EXPORT_OK = qw(delay_flash);

my %valid_categories = (
  map({$_ => 'info'} qw(information message)),
  map({$_ => $_}     qw(info error warning ok)),
);

#
# public functions
#

sub flash {
  $::form->{FLASH} = _store_flash($::form->{FLASH}, @_);
}

sub flash_later {
  # message and details are at index 1 and 2: make sure they are stored as strings,
  # as LoadBlessed is deactivated, and YAML::XS does not provide Stringify
  for my $i (1, 2) {
    $_[$i] .=  '' if defined $_[$i];
  }
  $::auth->set_session_value({ key => "FLASH", value => _store_flash($::auth->get_session_value('FLASH'), @_), auto_restore => 1 });
}

sub flash_contents {
  return unless $::form;
  return unless $::form->{FLASH};
  return unless 'ARRAY' eq ref $::form->{FLASH};

  @{ $::form->{FLASH} }
}

sub delay_flash {
  my $store = $::form->{FLASH} || [];
  flash_later(@{ $_ || [] }) for @$store;
}

#
# private functions
#

sub _store_flash {
  my ($store, $type, $message, $details, $timestamp) = @_;
  $store     //= [ ];
  $timestamp //= time();
  my $category = _check_category($type);

  push @{ $store }, [ $type, $message, $details, $timestamp ];

  return $store;
}

sub _check_category {
  my ($c) = @_;
  return $valid_categories{$c}
    ||  do {
      require Carp;
      Carp->import;
      croak("invalid category '$c' for flash");
    };
}

1;

__END__

=head1 NAME

SL::Helper::Flash - helper functions for storing messages to be
displayed to the user

=head1 SYNOPSIS

  use SL::Helper::Flash qw(flash flash_later delay_flash);

  # display in this request
  flash('info', 'Customer saved!');
  flash('error', 'Something went wrong', "details about what went wrong");
  flash('warning', 'this might not be a good idea');

  # display after a redirect
  flash_later('info', 'Customer saved!');
  flash_later('error', 'Something went wrong', "details about what went wrong");
  flash_later('warning', 'this might not be a good idea');

  # delay flash() calls to next request:
  delay_flash();

=head1 DESCRIPTION

The flash is a store for messages that should be displayed to the
user. Each message has a category which is usually C<information>,
C<warning> or C<error>. The messages in each category are grouped and
displayed in colors appropriate for their severity (e.g. errors in
red).

Messages are rendered by including the L<SL::Layout::Flash> sub layout.

=head1 EXPORTS

The functions L</flash> and L</flash_later> are always exported.

=head1 FUNCTIONS

=over 4

=item C<flash $category, $message [, $details ]>

Store a message with optional details for the given category. The category can
be either C<information>, C<warning> or C<error>. C<info> can also be used as
an alias for C<information>.

The C<$message> and C<$details> are escaped by the C<flash> and
C<flash_later> functions, preserving line breaks.

=item C<flash_later $category, $message [, $details ]>

Store a message with optional details for the given category for the next
request. The category can be either C<information>, C<warning> or C<error>.
C<info> can also be used as an alias for C<information>.

The message is stored in the user's session and restored upon the
next request. Can be used for transmitting information over HTTP
redirects.

=item C<delay_flash>

Delays flash, as if all flash messages in this request would have been
C<flash_later>

Not exported by default.

=item C<flash_contents>

The contents of the current flash accumulator.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
