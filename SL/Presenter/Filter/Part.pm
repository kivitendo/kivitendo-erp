package SL::Presenter::Filter::Part;

use parent SL::Presenter::Filter;

use strict;

use SL::Locale::String qw(t8);

use Params::Validate qw(:all);

sub get_default_filter_elements {
  my ($filter) = @_;

  my %default_filter_elements = ( # {{{
    part_data => {
      'position' => 1,
      'text' => t8('Article data'),
      'input_type' => 'input_group',
      'input_values' => {
        'partnumber' => {
          'position' => 1,
          'text' => t8("Partnumber"),
          'input_type' => 'input_tag',
          'input_name' => 'filter.partnumber:substr::ilike',
          'input_default' => $filter->{'partnumber:substr::ilike'},
          'report_id' => 'partnumber',
          'active' => 1,
        },
        'ean' => {
          'position' => 2,
          'text' => t8("EAN"),
          'input_type' => 'input_tag',
          'input_name' => 'filter.ean:substr::ilike',
          'input_default' => $filter->{'ean:substr::ilike'},
          'report_id' => 'ean',
          'active' => 1,
        },
        'description' => {
          'position' => 3,
          'text' => t8("Part Description"),
          'input_type' => 'input_tag',
          'input_name' => 'filter.description:substr::ilike',
          'input_default' => $filter->{'description:substr::ilike'},
          'report_id' => 'description',
          'active' => 1,
        },
        'notes' => {
          'position' => 4,
          'text' => t8("Notes"),
          'input_type' => 'input_tag',
          'input_name' => 'filter.notes:substr::ilike',
          'input_default' => $filter->{'notes:substr::ilike'},
          'report_id' => 'notes',
          'active' => 1,
        },
        'partsgroup' => {
          'position' => 5,
          'text' => t8("Partsgroup"),
          'input_type' => 'input_tag',
          'input_name' => 'filter.partsgroup.partsgroup:substr::ilike',
          'input_default' => $filter->{partsgroup}->{'partsgroup:substr::ilike'},
          'report_id' => 'partsgroup',
          'active' => 1,
        },
      },
      'input_name' => 'part_data',
      'active' => 1,
    },
  ); # }}}
  return \%default_filter_elements;
}

sub get_price_change_printed_filter {
  my ($filter) = @_;
  my %part_label_print_filter = (
    price_change_printed => {
      'position' => 0.5,
      'text' => t8('Price Change Printed'),
      'input_type' => 'input_group',
      'input_values' => {
        'template' => {
          'position' => 1,
          'text' => t8("Template"),
          'input_type' => 'select_tag',
          'input_values' => [
            ['' => ''],
            ['part_label' => t8('Part label')],
            ['part_info' => t8('Part info')],
          ],
          'input_name' => 'filter.price_change_printed.template:struct',
          'input_default' => $filter->{price_change_printed}->{'template:struct'},
          'active' => 1,
        },
        'print_type' => {
          'position' => 2,
          'text' => t8("Print Type"),
          'input_type' => 'select_tag',
          'input_values' => [
            ['' => ''],
            ['stock' => t8('Stock')],
            ['single' => t8('Single')],
          ],
          'input_name' => 'filter.price_change_printed.print_type:struct',
          'input_default' => $filter->{price_change_printed}->{'print_type:struct'},
          'active' => 1,
        },
        'printed' => {
          'position' => 3,
          'text' => t8("Printed"),
          'input_type' => 'select_tag',
          'input_values' => [['0' => t8('No')], ['1' => t8('Yes')]],
          'input_name' => 'filter.price_change_printed.printed:struct',
          'input_default' => $filter->{price_change_printed}->{'printed:struct'},
          'active' => 1,
        },
      },
      'input_name' => 'price_change_printed_group',
      'active' => 1,
    },
  );
  return \%part_label_print_filter
}

sub filter {
  my $filter = shift @_;
  die "filter has to be a hash ref" if ref $filter ne 'HASH';
  my %params = validate_with(
    params => \@_,
    spec => {
    },
    allow_extra => 1,
  );

  my $filter_elements = get_default_filter_elements($filter);
  if(delete $params{show_price_change_printed_filter}) {
    $filter_elements = {
      %{$filter_elements},
      %{get_price_change_printed_filter($filter)}
    }
  }

  return SL::Presenter::Filter::create_filter($filter_elements, %params);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Filter::Reclamation - Presenter module for a generic Filter on
Reclamation.

=head1 SYNOPSIS

  # in Reclamation Controller
  my $filter_html = SL::Presenter::Filter::Reclamation::filter(
    $::form->{filter}, $self->type, active_in_report => $::form->{active_in_report}
  );


=head1 FUNCTIONS

=over 4

=item C<filter $filter, $reclamation_type, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of a filter form for reclamations of type
C<$reclamation_type>.

C<$filter> should be the C<filter> value of the last C<$::form>. This is used to
get the previous values of the input fields.

C<%params> fields get forwarded to C<SL::Presenter::Filter::create_filter>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
