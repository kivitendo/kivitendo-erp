package SL::Presenter::Filter;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(html_tag input_tag select_tag date_tag checkbox_tag);
use SL::Locale::String qw(t8);

use Carp;
use List::Util qw(min);
use Params::Validate qw(:all);

sub create_filter {
  validate_pos(@_,
    {
      type => HASHREF,
      default => {},
      callbacks => {
        has_all_keys => sub {
          foreach my $main_key (keys %{$_[0]}) {
            foreach my $sub_key (qw(
                position text input_type input_name
              )) {
              return die "Key '$sub_key' is missing under '$main_key'."
                unless exists $_[0]->{$main_key}->{$sub_key};
            }
          }
          return 1;
        }
      },
    },
    (0) x (@_ - 1) # allow extra parameters
  );
  my $filter_elements = shift @_;
  my %params = validate_with(
    params => \@_,
    spec   => {
    },
    allow_extra => 1,
  );

  my @filter_element_params =
    sort { $a->{position} <=> $b->{position} }
    grep { $_->{active} }
    values %{$filter_elements};

  my @filter_elements;
  for my $filter_element_param (@filter_element_params) {

    my $filter_element = _create_input_element($filter_element_param, %params);

    push @filter_elements, $filter_element;
  }

  my $filter_form_div = _create_filter_form(\@filter_elements, %params);

  is_escaped($filter_form_div);
}

sub _create_input_element {
  my $element_param = shift @_;
  my %params = validate_with(
    params => \@_,
    spec   => {
      no_show => {
        type => BOOLEAN,
        default => 0
      },
      active_in_report => {
        type => HASHREF,
        default => {}
      },
    },
    allow_extra => 1,
  );

  my $element_th;

  if($element_param->{input_type} eq 'input_group') {
    $element_th = html_tag('th', $element_param->{text},
      align => 'right',
      colspan => 2,
      class => "caption",
    );
  } else {
    $element_th = html_tag('th', $element_param->{text}, align => 'right');
  }

  my $element_input = '';

  if($element_param->{input_type} eq 'input_group') {

    my @filter_element_params =
      sort { $a->{position} <=> $b->{position} }
      grep { $_->{active} }
      values %{$element_param->{input_values}};


    my @filter_elements;
    for my $filter_element_param (@filter_element_params) {
      my $filter_element = _create_input_element($filter_element_param, %params);
      push @filter_elements, $filter_element;
    }

    $element_input = join('', map{html_tag('tr',$_)} @filter_elements);
    $element_input .= html_tag('tr');
  } elsif($element_param->{input_type} eq 'input_tag') {

    $element_input = input_tag($element_param->{input_name}, $element_param->{input_default});

  } elsif ($element_param->{input_type} eq 'select_tag') {

    $element_input = select_tag($element_param->{input_name}, $element_param->{input_values}, default => $element_param->{input_default})

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
  } else {
    confess "unknown input_type " . $element_param->{input_type};
  }

  my $element_input_td =  html_tag('td',
    $element_input,
    nowrap => 1,
  );

  my $element_checkbox_td =  '';
  unless($params{no_show} || $element_param->{report_id} eq '') {
    my $checkbox =  checkbox_tag(
      'active_in_report.' . $element_param->{report_id},
      checked => $params{active_in_report}->{$element_param->{report_id}},
      for_submit => 1
    );
    $element_checkbox_td = html_tag('td', $checkbox);
  }

  return $element_th . $element_input_td . $element_checkbox_td;
}

sub _create_filter_form {
  my $ref_elements = shift @_;
  my %params = validate_with(
    params => \@_,
    spec   => {
    },
    allow_extra => 1,
  );

  my $filter_table = _create_input_div($ref_elements, %params);

  my $filter_form = html_tag('form', $filter_table, method => 'post', action => 'controller.pl', id => 'filter_form');

  return $filter_form;
}

sub _create_input_div {
  my $ref_elements = shift @_;
  my %params = validate_with(
    params => \@_,
    spec => {
      count_columns => {
        type => SCALAR,
        default => 4,
      },
      no_show => {
        type => BOOLEAN,
        default => 0,
      },
    },
    allow_extra => 1,
  );
  my @elements = @{$ref_elements};
  my $count_elements = scalar(@elements);
  my $count_columns = min($count_elements, $params{count_columns});

  my $div_columns = "";
  my $start_index = 0;
  my $min_elements_per_column = int(($count_elements) / $count_columns);
  for my $i (0 .. ($count_columns - 1)) {
    my $elements_in_cloumn = $min_elements_per_column
      + (($count_elements % $count_columns) > $i ? 1 : 0);

    my $rows = "";
    for my $j (0 .. ($elements_in_cloumn - 1) ) {
      my $idx = $start_index + $j;
      my $element = $elements[$idx];
      $rows .= html_tag('tr', $element);

    }
    $start_index += $elements_in_cloumn;
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

SL::Presenter::Filter - Presenter module for a generic Filter.

=head1 SYNOPSIS

  my $filter_elements = {
    id => {
      'position' => 1,
      'text' => t8("ID"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.id:number',
      'input_default' => $::form->{filter}->{'id:number'},
      'report_id' => 'id',
      'active' => 1,
    },
    # ...
  };

  my $filter_html = SL::Presenter::Filter::create_filter(
    $filter_elements,
    active_in_report => ['id'],
  );


=head1 FUNCTIONS

=over 4

=item C<create_filter $filter_elements, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of a filter form for reclamations of type
C<$reclamation_type>.

C<$filter_elements> is a hash reference with the values declaring which inputs
to create.

=over 2

FILTER ELEMENTS

A filter element is a hash reference. Each filter has a unique key and can have
entries for:

=over 4

=item * position (mandatory)

Is a number after which the elements are ordered. This can be a float.

=item * text (mandatory)

Is shown before the input field.

=item * input_name (mandatory)

C<input_name> is used to set the name of the field, which should match the
filter syntax.

=item * C<input_type> (mandatory)

This must be C<input_tag>, C<select_tag>, C<yes_no_tag> or C<date_tag>. It sets
the input type for the filter.

=over 2

=item * C<input_tag>

Creates a text input field. The default value of this field is set to the
C<input_default> entry of the filter element.

=item * C<select_tag>

Creates a drop down field. C<input_values> is used to set the options.
See L<SL::Presenter::Tag::select_tag> for more details. The default value
of this field is set to the C<input_default> entry.

=item * C<yes_no_tag>

Creates a yes/no input field. The default value of this field is set to the
C<input_default> entry.

=item * C<date_tag>

Creates two date input fields. One filters for after the date and the other
filters for before the date. The default values of these fields are set to the
C<input_default_ge> and C<input_default_le> entries of the filter element.
For the first field ":date::ge" and for the second ":date::le" is added to the
end of C<input_name>.

=back

=item * C<report_id>

Is used to generate the id of the check box after the input field. The value of
the check box can be found in the form under
C<$::form-E<gt>{'active_in_report'}-E<gt>{report_id}>.

=item * C<active>

If falsish the element is ignored.

=item * C<input_default>, C<input_default_ge>, C<input_default_le>

Look at C<input_tag> to see how they are used.

=back

=back

C<%params> can include:

=over 2

=item * no_show

If falsish (the default) then a check box is added after the input field. Which
specifies whether the corresponding column appears in the report. The value of
the check box can be changed by the user.

=item * active_in_report

If C<$params{no_show}> is falsish, this is used to set the values of the check
boxes, after the input fields. This should be set to the C<active_in_report>
value of the last C<$::form>.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
