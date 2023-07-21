package SL::Presenter::ReclamationFilter;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(html_tag input_tag select_tag date_tag checkbox_tag);
use SL::Locale::String qw(t8);

use Exporter qw(import);
our @EXPORT_OK = qw(
filter
);

use Carp;

sub filter {
  my ($filter, $reclamation_type, %params) = @_;

  $filter ||= undef; #filter should not be '' (empty string);
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
      'input_default' =>$filter->{'id:number'},
      'report_id' => 'id',
      'active' => 0,
    },
    'record_number' => {
      'position' => 3,
      'text' => t8("Reclamation Number"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.record_number:substr::ilike',
      'input_default' =>$filter->{'record_number:substr::ilike'},
      'report_id' => 'record_number',
      'active' => 1,
    },
    'employee' => {
      'position' => 4,
      'text' => t8("Employee Name"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.employee.name:substr::ilike',
      'input_default' =>$filter->{employee}->{'name:substr::ilike'},
      'report_id' => 'employee',
      'active' => 1,
    },
    'salesman' => {
      'position' => 5,
      'text' => t8("Salesman Name"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.salesman.name:substr::ilike',
      'input_default' =>$filter->{salesman}->{'name:substr::ilike'},
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
      'input_default' =>$filter->{contact}->{'cp_name:substr::ilike'},
      'report_id' => 'contact',
      'active' => 1,
    },
    'language_code' => {
      'position' => 9,
      'text' => t8("Language Code"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.language.article_code:substr::ilike',
      'input_default' =>$filter->{language}->{'article_code:substr::ilike'},
      'report_id' => 'language',
      'active' => 1,
    },
    'department_description' => {
      'position' => 10,
      'text' => t8("Department Description"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.department.description:substr::ilike',
      'input_default' =>$filter->{department}->{'description:substr::ilike'},
      'report_id' => 'department',
      'active' => 1,
    },
    'globalproject_projectnumber' => {
      'position' => 11,
      'text' => t8("Project Number"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.globalproject.projectnumber:substr::ilike',
      'input_default' =>$filter->{globalproject}->{'projectnumber:substr::ilike'},
      'report_id' => 'globalproject',
      'active' => 1,
    },
    'globalproject_description' => {
      'position' => 12,
      'text' => t8("Project Description"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.globalproject.description:substr::ilike',
      'input_default' =>$filter->{globalproject}->{'description:substr::ilike'},
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
      'input_default' =>$filter->{'transaction_description:substr::ilike'},
      'report_id' => 'transaction_description',
      'active' => 1,
    },
    'notes' => {
      'position' => 15,
      'text' => t8("Notes"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.notes:substr::ilike',
      'input_default' =>$filter->{'notes:substr::ilike'},
      'report_id' => 'notes',
      'active' => 1,
    },
    'intnotes' => {
      'position' => 16,
      'text' => t8("Internal Notes"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.intnotes:substr::ilike',
      'input_default' =>$filter->{'intnotes:substr::ilike'},
      'report_id' => 'intnotes',
      'active' => 1,
    },
    'shippingpoint' => {
      'position' => 17,
      'text' => t8("Shipping Point"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.shippingpoint:substr::ilike',
      'input_default' =>$filter->{'shippingpoint:substr::ilike'},
      'report_id' => 'shippingpoint',
      'active' => 1,
    },
    'shipvia' => {
      'position' => 18,
      'text' => t8("Ship via"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.shipvia:substr::ilike',
      'input_default' =>$filter->{'shipvia:substr::ilike'},
      'report_id' => 'shipvia',
      'active' => 1,
    },
    # 'shipto_block'{
      'shipto_name' => {
        'position' => 18.1,
        'text' => t8("Name"),
        'input_type' => 'input_tag',
        'input_name' => 'filter.shipto_name:substr::ilike',
        'input_default' => $filter->{'shipto_name:substr::ilike'},
        'report_id' => 'shipto_name',
        'active' => 1,
      },
      'shipto_department' => {
        'position' => 18.2,
        'text' => t8("Department"),
        'input_type' => 'input_tag',
        'input_name' => 'filter.shipto_department:substr::ilike',
        'input_default' => $filter->{'shipto_department:substr::ilike'},
        'report_id' => 'shipto_department',
        'active' => 1,
      },
      'shipto_street' => {
        'position' => 18.3,
        'text' => t8("Street"),
        'input_type' => 'input_tag',
        'input_name' => 'filter.shipto_street:substr::ilike',
        'input_default' => $filter->{'shipto_street:substr::ilike'},
        'report_id' => 'shipto_street',
        'active' => 1,
      },
      'shipto_zipcode' => {
        'position' => 18.4,
        'text' => t8("Zipcode"),
        'input_type' => 'input_tag',
        'input_name' => 'filter.shipto_zipcode:substr::ilike',
        'input_default' => $filter->{'shipto_zipcode:substr::ilike'},
        'report_id' => 'shipto_zipcode',
        'active' => 1,
      },
      'shipto_city' => {
        'position' => 18.5,
        'text' => t8("City"),
        'input_type' => 'input_tag',
        'input_name' => 'filter.shipto_city:substr::ilike',
        'input_default' => $filter->{'shipto_city:substr::ilike'},
        'report_id' => 'shipto_city',
        'active' => 1,
      },
      'shipto_country' => {
        'position' => 18.6,
        'text' => t8("Country"),
        'input_type' => 'input_tag',
        'input_name' => 'filter.shipto_country:substr::ilike',
        'input_default' => $filter->{'shipto_country:substr::ilike'},
        'report_id' => 'shipto_country',
        'active' => 1,
      },
    # }
    'amount' => {
      'position' => 19,
      'text' => t8("Total"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.amount:number',
      'input_default' =>$filter->{'amount:number'},
      'report_id' => 'amount',
      'active' => 1,
    },
    'netamount' => {
      'position' => 20,
      'text' => t8("Subtotal"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.netamount:number',
      'input_default' =>$filter->{'netamount:number'},
      'report_id' => 'netamount',
      'active' => 1,
    },
    'delivery_term_description' => {
      'position' => 21,
      'text' => t8("Delivery Terms"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.delivery_term.description:substr::ilike',
      'input_default' =>$filter->{delivery_term}->{'description:substr::ilike'},
      'report_id' => 'delivery_term',
      'active' => 1,
    },
    'payment_description' => {
      'position' => 22,
      'text' => t8("Payment Terms"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.payment.description:substr::ilike',
      'input_default' =>$filter->{payment}->{'description:substr::ilike'},
      'report_id' => 'payment',
      'active' => 1,
    },
    'currency_name' => {
      'position' => 23,
      'text' => t8("Currency"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.currency.name:substr::ilike',
      'input_default' =>$filter->{currency}->{'name:substr::ilike'},
      'report_id' => 'currency',
      'active' => 1,
    },
    'exchangerate' => {
      'position' => 24,
      'text' => t8("Exchangerate"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.exchangerate:number',
      'input_default' =>$filter->{'exchangerate:number'},
      'report_id' => 'exchangerate',
      'active' => 1,
    },
    'taxincluded' => {
      'position' => 25,
      'text' => t8("Tax Included"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.taxincluded',
      'input_default' =>$filter->{taxincluded},
      'report_id' => 'taxincluded',
      'active' => 1,
    },
    'taxzone_description' => {
      'position' => 26,
      'text' => t8("Tax zone"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.taxzone.description:substr::ilike',
      'input_default' =>$filter->{taxzone}->{'description:substr::ilike'},
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
      'input_default' =>$filter->{delivered},
      'report_id' => 'delivered',
      'active' => 1,
    },
    'closed' => {
      'position' => 33,
      'text' => t8("Closed"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.closed',
      'input_default' =>$filter->{closed},
      'report_id' => 'closed',
      'active' => 1,
    },
  ); # }}}

  # combine default and param values for filter_element,
  # only replace the lowest occurrence
  my %filter_elements = %default_filter_elements;
  while(my ($key, $value) = each (%{$params{filter_elements}})) {
    if(exists $filter_elements{$key}) {
      $filter_elements{$key} = ({
        %{$filter_elements{$key}},
        %{$value},
      });
    } else {
      $filter_elements{$key} = $value;
    }
  }

  my @filter_element_params =
    sort { $a->{position} <=> $b->{position} }
    grep { $_->{active} }
    values %filter_elements;

  my @filter_elements;
  for my $filter_element_param (@filter_element_params) {
    unless($filter_element_param->{active}) {
      next;
    }

    my $filter_element = _create_input_element($filter_element_param, %params);

    push @filter_elements, $filter_element;
  }

  my $filter_form_div = _create_filter_form(\@filter_elements, %params);

  is_escaped($filter_form_div);
}

sub _create_input_element {
  my ($element_param, %params) = @_;

  my $element_th =  html_tag('th', $element_param->{text}, align => 'right');

  my $element_input = '';

  if($element_param->{input_type} eq 'input_tag') {

    $element_input = input_tag($element_param->{input_name}, $element_param->{input_default});

  } elsif ($element_param->{input_type} eq 'yes_no_tag') {

    $element_input = select_tag($element_param->{input_name}, [ [ 1 => t8('Yes') ], [ 0 => t8('No') ] ], default => $element_param->{input_default}, with_empty => 1)

  } elsif($element_param->{input_type} eq 'date_tag') {

    my $after_input =
      html_tag('th', t8("After"), align => 'right') .
      html_tag('td',
        date_tag("filter." . $element_param->{input_name} . ":date::ge", $element_param->{input_default_ge})
      )
    ;
    my $before_input =
      html_tag('th', t8("Before"), align => 'right') .
      html_tag('td',
        date_tag("filter." . $element_param->{input_name} . ":date::le", $element_param->{input_default_le})
      )
    ;

    $element_input =
      html_tag('table',
        html_tag('tr', $after_input)
        .
        html_tag('tr', $before_input)
      )
    ;
  }

  my $element_input_td =  html_tag('td',
    $element_input,
    nowrap => 1,
  );

  my $element_checkbox_td =  '';
  unless($params{no_show} || $element_param->{report_id} eq '') {
    my $checkbox =  checkbox_tag('active_in_report.' . $element_param->{report_id}, checked => $params{active_in_report}->{$element_param->{report_id}}, for_submit => 1);
    $element_checkbox_td = html_tag('td', $checkbox);
  }

  return $element_th . $element_input_td . $element_checkbox_td;
}

sub _create_filter_form {
  my ($ref_elements, %params) = @_;

  my $filter_table = _create_input_div($ref_elements, %params);

  my $filter_form = html_tag('form', $filter_table, method => 'post', action => 'controller.pl', id => 'search_form');

  return $filter_form;
}

sub _create_input_div {
  my ($ref_elements, %params) = @_;
  my @elements = @{$ref_elements};

  my $div_columns = "";

  $params{count_columns} ||= 4;
  my $elements_per_column = (int((scalar(@{$ref_elements}) - 1) / $params{count_columns}) + 1);
  for my $i (0 .. ($params{count_columns} - 1)) {

    my $rows = "";
    for my $j (0 .. ($elements_per_column - 1) ) {
      my $idx = $elements_per_column * $i + $j;
      my $element = $elements[$idx];
      $rows .= html_tag('tr', $element);

    }
    $div_columns .= html_tag('div',
      html_tag('table',
        html_tag('tr',
          html_tag('td')
          . html_tag('th', t8('Filter'))
          . ( $params{no_show} ? '' : html_tag('th', t8('Show')) )
        )
        . $rows
      ),
      style => "flex:1");
  }

  my $input_div = html_tag('div', $div_columns, style => "display:flex;flex-wrap:wrap");

  return $input_div;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::ReclamationFilter - Presenter module for a generic Filter on
Reclamation.

=head1 SYNOPSIS

  # in Reclamation Controller
  my $filter_html = SL::Presenter::ReclamationFilter::filter(
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

C<%params> can include:

=over 2

=item * no_show

If falsish (the default) then a check box is added after the input field. Which
specifies whether the corresponding column appears in the report. The value of
the check box can be changed by the user.

=item * active_in_report

If C<$params{no_show}> is falsish, this is used to set the values of the check
boxes, after the input fields. This can be set to the C<active_in_report> value
of the last C<$::form>.

=item * filter_elements

Is combined with the default filter elements. This can be used to override
default values of the filter elements or to add a new ones.

  #deactivate the id and record_number fields
  $params{filter_elements} = ({
    id => {active => 0},
    record_number => {active => 0}
  });

=back

=back

=head1 FILTER ELEMENTS

A filter element is stored in and as a hash map. Each filter has a unique key
and should have entries for:

=over 4

=item * position

Is a number after which the elements are ordered. This can be a float.

=item * text

Is shown before the input field.

=item * input_type

This must be C<input_tag>, C<yes_no_tag> or C<date_tag>. It sets the input type
for the filter.

=over 2

=item * input_tag

Creates a text input field. The default value of this field is set to the
C<input_default> entry of the filter element. C<input_name> is used to set the
name of the field, which should match the filter syntax.

=item * yes_no_tag

Creates a yes/no input field. The default value of this field is set to the
C<input_default> entry of the filter element. C<input_name> is used to set the
name of the field, which should match the filter syntax.

=item * date_tag

Creates two date input fields. One filters for after the date and the other
filters for before the date. The default values of these fields are set to the
C<input_default_ge> and C<input_default_le> entries of the filter element.
C<input_name> is used to set the names of these fields, which should match the
filter syntax. For the first field ":date::ge" and for the second ":date::le" is
added to the end of C<input_name>.

=back

=item * report_id

Is used to generate the id of the check box after the input field. The value of
the check box can be found in the form under
C<$::form-E<gt>{'active_in_report'}-E<gt>{report_id}>.

=item * active

If falsish the element is ignored.

=item * input_name, input_default, input_default_ge, input_default_le

Look at I<input_tag> to see how they are used.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
