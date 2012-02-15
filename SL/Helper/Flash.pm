package SL::Helper::Flash;

use strict;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT    = qw(flash flash_later);
our @EXPORT_OK = qw(render_flash delay_flash);

my %valid_categories = (
  map({$_ => 'info'} qw(information message)),
  map({$_ => $_}     qw(info error warning)),
);

#
# public functions
#

sub flash {
  $::form->{FLASH} = _store_flash($::form->{FLASH}, @_);
}

sub flash_later {
  $::auth->set_session_value({ key => "FLASH", value => _store_flash($::auth->get_session_value('FLASH'), @_), auto_restore => 1 });
}

sub delay_flash {
  my $store = $::form->{FLASH} || { };
  flash_later($_ => @{ $store->{$_} || [] }) for keys %$store;
}

sub render_flash {
  return $::form->parse_html_template('common/flash');
}

#
# private functions
#

sub _store_flash {
  my $store    = shift || { };
  my $category = _check_category(+shift);

  $store->{ $category } ||= [ ];
  push @{ $store->{ $category } }, @_;

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

The flash is a store for messages that should be displayed to the
user. Each message has a category which is usually C<information>,
C<warning> or C<error>. The messages in each category are grouped and
displayed in colors appropriate for their severity (e.g. errors in
red).

Messages are rendered either by calling the function C<render_flash>
or by including the flash sub-template from a template with the
following code:

  [%- INCLUDE 'common/flash.html' %]

=head1 EXPORTS

The functions L</flash> and L</flash_later> are always exported.

The function L</render_flash> is only exported upon request.

=head1 FUNCTIONS

=over 4

=item C<flash $category, @messages>

Stores messages for the given category. The category can be either
C<information>, C<warning> or C<error>. C<info> can also be used as an
alias for C<information>.

=item C<flash_later $category, @messages>

Stores messages for the given category for the next request. The
category can be either C<information>, C<warning> or C<error>. C<info>
can also be used as an alias for C<information>.

The messages are stored in the user's session and restored upon the
next request. Can be used for transmitting information over HTTP
redirects.

=item C<render_flash>

Outputs the flash message by parsing the C<common/flash.html> template
file.

This function is not exported by default.

=item C<delay_flash>

Delays flash, as if all flash messages in this request would have been
C<flash_later>

Not exported by default.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
