package SL::Helper::Flash;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(flash render_flash);

sub flash {
  my $category = shift;
  $category    = 'info' if $category eq 'information';

  $::form->{FLASH}                ||= { };
  $::form->{FLASH}->{ $category } ||= [ ];
  push @{ $::form->{FLASH}->{ $category } }, @_;
}

sub render_flash {
  return $::form->parse_html_template('common/flash');
}

1;

__END__

=head1 NAME

SL::Helpers::Flash - helper functions for storing messages to be
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

=head1 FUNCTIONS

=over 4

=item C<flash $category, $message>

Stores a message for the given category. The category can be either
C<information>, C<warning> or C<error>. C<info> can also be used as an
alias for C<information>.

=item C<render_flash>

Outputs the flash message by parsing the C<common/flash.html> template
file.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
