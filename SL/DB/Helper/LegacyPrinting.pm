package SL::DB::Helper::LegacyPrinting;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(map_keys_to_arrays format_as_number);

sub map_keys_to_arrays {
  my ($items, $keys, $template_arrays) = @_;

  for my $key (@$keys) {
    # handle nested keys
    if ($key =~ /\./) {
      my ($k1, $k2) = split /\./, $key;
      $template_arrays->{$k1} = [ map { { $k2 => $_->{$k1}->{$k2} } } @$items ];
    } else {
      $template_arrays->{$key} = [ map {
        if (ref $_ eq 'HASH') {
          $_->{$key}
        } else {
          $_->can($key) ? $_->$key
                        : $_->{$key}
        }
      } @$items ];
    }
  }
}

sub format_as_number {
  my ($keys, $template_arrays) = @_;

  for my $key (@$keys) {
    $template_arrays->{$key} = [ map {
      $::form->format_amount(\%::myconfig, $_, 2, 0),
    } @{ $template_arrays->{$key} } ];
  }
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::LegacyPrinting - Helper functions to support printing using the built-it template parser

=head1 DESCRIPTION

The new Reclamation controller, and possibly other future controllers, only support printing using Template Toolkit (TT)
for parsing the templates. For OpenDocument templates however, template toolkit cannot be used.

Template Toolkit (TT) can access Rose DB objects directly, which is a feature not available in the built-in parser.
For positions in a loop, such as positions in a table, the built-in parser expects the data in a specific format.
Therefore, we need to prepare the data accordingly before it can be processed by the built-in parser.

In the past this was done in the respective modules, e.g. SL/OE.pm. The idea would be to extract the data from the Rose
DB objects. That should hopefully result in less and simpler code.

=head1 FUNCTIONS

=head2 C<map_keys_to_arrays ($items, $keys, $template_arrays)>

Extracts the given keys from the given list of Rose DB objects and adds them to the given hash reference,
in the format that the built in template parser expects.

The expected format looks like the following, e.g.:

  # 'qty_as_number' => [
  #                      '1.00',
  #                      '3.00'
  #                    ],
  # 'part' => [
  #             {
  #               'partnumber' => '000013'
  #             },
  #             {
  #               'partnumber' => '000004'
  #             }
  #           ],
  # 'position' => [
  #                 1,
  #                 2
  #               ],
  # 'unit' => [
  #             'Stck',
  #             'Stck'
  #           ],

=over 4

=item C<$items>

A reference to a list of Rose DB objects from which the keys should be extracted.

=item C<$keys>

A reference to a list of keys that should be extracted from the Rose DB object.
Nested keys should be denoted by a dot. E.g.:

  qw( qty_as_number part.partnumber position unit )

=item C<$template_arrays>

A reference to a hash to which the extracted keys should be added.

=back

=head2 C<format_as_number ($keys, $template_arrays)>

Formats the given keys in the given hash reference as numbers.

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>
