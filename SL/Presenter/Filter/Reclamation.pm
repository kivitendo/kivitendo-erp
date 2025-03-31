package SL::Presenter::Filter::Reclamation;

use parent SL::Presenter::Filter;

use strict;

use SL::Locale::String qw(t8);

use Params::Validate qw(:all);

sub get_default_filter_elements {
  my ($filter, $reclamation_type) = @_;

  my %default_filter_elements = ( # {{{
    'reason_names' => {
      'position' => 1,
      'text' => t8("Reclamation Reason"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.reclamation_items.reason.name:substr::ilike',
      'input_default' => $filter->{reclamation_items}->{reason}->{'name:substr::ilike'},
      'active' => 1,
    },
    'id' => {
      'position' => 2,
      'text' => t8("Reclamation ID"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.id:number',
      'input_default' => $filter->{'id:number'},
      'report_id' => 'id',
      'active' => 0,
    },
    'record_number' => {
      'position' => 3,
      'text' => t8("Reclamation Number"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.record_number:substr::ilike',
      'input_default' => $filter->{'record_number:substr::ilike'},
      'report_id' => 'record_number',
      'active' => 1,
    },
    'employee' => {
      'position' => 4,
      'text' => t8("Employee Name"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.employee.name:substr::ilike',
      'input_default' => $filter->{employee}->{'name:substr::ilike'},
      'report_id' => 'employee',
      'active' => 1,
    },
    'salesman' => {
      'position' => 5,
      'text' => t8("Salesman Name"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.salesman.name:substr::ilike',
      'input_default' => $filter->{salesman}->{'name:substr::ilike'},
      'report_id' => 'salesman',
      'active' => 1,
    },
    # 6,7 for Customer/Vendor
    'customer' => {
      'position' => 6,
      'text' => t8("Customer Name"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.customer.name:substr::ilike',
      'input_default' => $filter->{customer}->{'name:substr::ilike'},
      'report_id' => 'customer',
      'active' => ($reclamation_type eq 'sales_reclamation' ? 1 : 0),
    },
    'vendor' => {
      'position' => 6,
      'text' => t8("Vendor Name"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.vendor.name:substr::ilike',
      'input_default' => $filter->{vendor}->{'name:substr::ilike'},
      'report_id' => 'vendor',
      'active' => ($reclamation_type eq 'purchase_reclamation' ? 1 : 0),
    },
    'customer_number' => {
      'position' => 7,
      'text' => t8("Customer Number"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.customer.customernumber:substr::ilike',
      'input_default' => $filter->{customer}->{'customernumber:substr::ilike'},
      'active' => ($reclamation_type eq 'sales_reclamation' ? 1 : 0),
    },
    'vendor_number' => {
      'position' => 7,
      'text' => t8("Vendor Number"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.vendor.vendornumber:substr::ilike',
      'input_default' => $filter->{vendor}->{'vendornumber:substr::ilike'},
      'active' => ($reclamation_type eq 'purchase_reclamation' ? 1 : 0),
    },
    'contact_name' => {
      'position' => 8,
      'text' => t8("Contact Name"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.contact.cp_name:substr::ilike',
      'input_default' => $filter->{contact}->{'cp_name:substr::ilike'},
      'report_id' => 'contact',
      'active' => 1,
    },
    'language_code' => {
      'position' => 9,
      'text' => t8("Language Code"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.language.article_code:substr::ilike',
      'input_default' => $filter->{language}->{'article_code:substr::ilike'},
      'report_id' => 'language',
      'active' => 1,
    },
    'department_description' => {
      'position' => 10,
      'text' => t8("Department Description"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.department.description:substr::ilike',
      'input_default' => $filter->{department}->{'description:substr::ilike'},
      'report_id' => 'department',
      'active' => 1,
    },
    'globalproject_projectnumber' => {
      'position' => 11,
      'text' => t8("Project Number"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.globalproject.projectnumber:substr::ilike',
      'input_default' => $filter->{globalproject}->{'projectnumber:substr::ilike'},
      'report_id' => 'globalproject',
      'active' => 1,
    },
    'globalproject_description' => {
      'position' => 12,
      'text' => t8("Project Description"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.globalproject.description:substr::ilike',
      'input_default' => $filter->{globalproject}->{'description:substr::ilike'},
      'active' => 1,
    },
    'cv_record_number' => {
      'position' => 13,
      'text' => ($reclamation_type eq 'sales_reclamation'
                  ? t8("Customer Record Number")
                  : t8("Vendor Record Number")
                ),
      'input_type' => 'input_tag',
      'input_name' => 'filter.cv_record_number:substr::ilike',
      'input_default' => $filter->{'cv_record_number:substr::ilike'},
      'report_id' => 'cv_record_number',
      'active' => 1,
    },
    'transaction_description' => {
      'position' => 14,
      'text' => t8("Description"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.transaction_description:substr::ilike',
      'input_default' => $filter->{'transaction_description:substr::ilike'},
      'report_id' => 'transaction_description',
      'active' => 1,
    },
    'notes' => {
      'position' => 15,
      'text' => t8("Notes"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.notes:substr::ilike',
      'input_default' => $filter->{'notes:substr::ilike'},
      'report_id' => 'notes',
      'active' => 1,
    },
    'intnotes' => {
      'position' => 16,
      'text' => t8("Internal Notes"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.intnotes:substr::ilike',
      'input_default' => $filter->{'intnotes:substr::ilike'},
      'report_id' => 'intnotes',
      'active' => 1,
    },
    'shippingpoint' => {
      'position' => 17,
      'text' => t8("Shipping Point"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.shippingpoint:substr::ilike',
      'input_default' => $filter->{'shippingpoint:substr::ilike'},
      'report_id' => 'shippingpoint',
      'active' => 1,
    },
    'shipvia' => {
      'position' => 18,
      'text' => t8("Ship via"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.shipvia:substr::ilike',
      'input_default' => $filter->{'shipvia:substr::ilike'},
      'report_id' => 'shipvia',
      'active' => 1,
    },
    'amount' => {
      'position' => 19,
      'text' => t8("Total"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.amount:number',
      'input_default' => $filter->{'amount:number'},
      'report_id' => 'amount',
      'active' => 1,
    },
    'netamount' => {
      'position' => 20,
      'text' => t8("Subtotal"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.netamount:number',
      'input_default' => $filter->{'netamount:number'},
      'report_id' => 'netamount',
      'active' => 1,
    },
    'delivery_term_description' => {
      'position' => 21,
      'text' => t8("Delivery Terms"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.delivery_term.description:substr::ilike',
      'input_default' => $filter->{delivery_term}->{'description:substr::ilike'},
      'report_id' => 'delivery_term',
      'active' => 1,
    },
    'payment_description' => {
      'position' => 22,
      'text' => t8("Payment Terms"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.payment.description:substr::ilike',
      'input_default' => $filter->{payment}->{'description:substr::ilike'},
      'report_id' => 'payment',
      'active' => 1,
    },
    'currency_name' => {
      'position' => 23,
      'text' => t8("Currency"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.currency.name:substr::ilike',
      'input_default' => $filter->{currency}->{'name:substr::ilike'},
      'report_id' => 'currency',
      'active' => 1,
    },
    'exchangerate' => {
      'position' => 24,
      'text' => t8("Exchangerate"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.exchangerate:number',
      'input_default' => $filter->{'exchangerate:number'},
      'report_id' => 'exchangerate',
      'active' => 1,
    },
    'taxincluded' => {
      'position' => 25,
      'text' => t8("Tax Included"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.taxincluded',
      'input_default' => $filter->{taxincluded},
      'report_id' => 'taxincluded',
      'active' => 1,
    },
    'taxzone_description' => {
      'position' => 26,
      'text' => t8("Tax zone"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.taxzone.description:substr::ilike',
      'input_default' => $filter->{taxzone}->{'description:substr::ilike'},
      'report_id' => 'taxzone',
      'active' => 1,
    },
    'tax_point' => {
      'position' => 27,
      'text' => t8("Tax point"),
      'input_type' => 'date_tag',
      'input_name' => 'tax_point',
      'input_default_ge' => $filter->{'tax_pont' . ':date::ge'},
      'input_default_le' => $filter->{'tax_pont' . ':date::le'},
      'report_id' => 'tax_point',
      'active' => 1,
    },
    'reqdate' => {
      'position' => 28,
      'text' => t8("Deadline"),
      'input_type' => 'date_tag',
      'input_name' => 'reqdate',
      'input_default_ge' => $filter->{'reqdate' . ':date::ge'},
      'input_default_le' => $filter->{'reqdate' . ':date::le'},
      'report_id' => 'reqdate',
      'active' => 1,
    },
    'transdate' => {
      'position' => 29,
      'text' => t8("Booking Date"),
      'input_type' => 'date_tag',
      'input_name' => 'transdate',
      'input_default_ge' => $filter->{'transdate' . ':date::ge'},
      'input_default_le' => $filter->{'transdate' . ':date::le'},
      'report_id' => 'transdate',
      'active' => 1,
    },
    'itime' => {
      'position' => 30,
      'text' => t8("Creation Time"),
      'input_type' => 'date_tag',
      'input_name' => 'itime',
      'input_default_ge' => $filter->{'itime' . ':date::ge'},
      'input_default_le' => $filter->{'itime' . ':date::le'},
      'report_id' => 'itime',
      'active' => 1,
    },
    'mtime' => {
      'position' => 31,
      'text' => t8("Last modification Time"),
      'input_type' => 'date_tag',
      'input_name' => 'mtime',
      'input_default_ge' => $filter->{'mtime' . ':date::ge'},
      'input_default_le' => $filter->{'mtime' . ':date::le'},
      'report_id' => 'mtime',
      'active' => 1,
    },
    'delivered' => {
      'position' => 32,
      'text' => t8("Delivered"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.delivered',
      'input_default' => $filter->{delivered},
      'report_id' => 'delivered',
      'active' => 1,
    },
    'closed' => {
      'position' => 33,
      'text' => t8("Closed"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.closed',
      'input_default' => $filter->{closed},
      'report_id' => 'closed',
      'active' => 1,
    },
  ); # }}}
  return \%default_filter_elements;
}

sub filter {
  my $filter = shift @_;
  die "filter has to be a hash ref" if ref $filter ne 'HASH';
  my $reclamation_type = shift @_;
  my %params = validate_with(
    params => \@_,
    spec   => {
    },
    allow_extra => 1,
  );

  # combine default and param values for filter_element,
  # only replace the lowest occurrence
  my $filter_elements = get_default_filter_elements($filter, $reclamation_type);

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
