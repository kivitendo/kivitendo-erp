# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::History;

use strict;

use SL::DB::MetaSetup::History;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub parsed_snumber {
  my ($self) = @_;

  my ($snumber) = $self->snumbers =~ /^.*?_(.*)/;
  return $snumber ? $snumber : $self->snumbers;
}

1

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::History: Model for the 'history_erp' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 METHODS

=over 4

=item C<parsed_snumber>

The column snumbers contains entries such as "partnumber_3" or
"customernumber_23".

To be able to print only the number, parsed_snumber returns only the part of
the string following the first "_".

Returns the whole string if the regex doesn't match anything.

=back

=head1 AUTHORS

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut

1;
