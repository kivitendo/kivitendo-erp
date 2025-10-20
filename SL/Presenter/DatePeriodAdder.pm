package SL::Presenter::DatePeriodAdder;

use strict;

use Exporter qw(import);
our @EXPORT_OK = qw(date_period_adder adder get_date_periods get_hidden_variables_for_report);

use SL::Presenter::Tag qw(name_to_id hidden_tag div_tag button_tag html_tag);
use SL::Presenter::DatePeriod qw(date_period_picker);

sub date_period_adder {
  my ($name_prefix, %params) = @_;

  my $id_prefix    = name_to_id($name_prefix);
  my $button_text  = $params{button_text} // $::locale->text('Add Date Period');
  my $container_id = $id_prefix . '_container';
  my $counter_id   = $id_prefix . '_counter';
  my $button_id    = $id_prefix . '_add_button';

  my $html = '';

  my $date_period_picker_html = date_period_picker("${id_prefix}_0");

  $html .= qq|<div id="${id_prefix}_adder" class="dateperiod-adder flex-flow-column gap-10">|;
  $html .= qq|  <input type="hidden" id="$counter_id" value="1" />|;
  $html .= qq|  <div id="$container_id" class="flex-flow-column gap-10">|;
  $html .= qq|    ${date_period_picker_html}|;
  $html .= qq|    <input type="hidden" name="${id_prefix}_names[]" value="${id_prefix}_0">|;
  $html .= qq|  </div>|;
  $html .= qq|  <div><button type="button" id="$button_id" class="neutral" onclick="kivi.DatePeriodAdder.add('$id_prefix')">$button_text</button></div>|;
  $html .= qq|</div>|;

  $::request->layout->add_javascripts('kivi.Presenter.DatePeriodAdder.js');

  return $html;
}

sub adder { goto &date_period_adder }

### helper

sub get_date_periods {
  my ($form, $name_prefix) = @_;

  my $date_period_names = $form->{"${name_prefix}_names"};

  my @date_periods;
  my $idx = 0;
  for my $name (@{$date_period_names}) {
    my $from_date = $form->{"${name}_from_date"};
    my $to_date   = $form->{"${name}_to_date"};
    my %date = (
      from => $from_date,
      to   => $to_date,
      index => $idx,
      name  => $name,
      from_dateobj => $::locale->parse_date_to_object($from_date),
      to_dateobj   => $::locale->parse_date_to_object($to_date),
    );
    push @date_periods, \%date;
    $idx++;
  }
  return \@date_periods;
}

sub get_hidden_variables_for_report {
  my ($form, $name_prefix) = @_;
  my $date_periods = get_date_periods($form, $name_prefix);

  my @hidden_vars;
  # for the report we need to carry the input elements containing the actual
  # dates
  for my $p (@$date_periods) {
    push @hidden_vars, "$p->{name}_from_date";
    push @hidden_vars, "$p->{name}_to_date";
  }
  # as well as the elements containing the names of the date periods
  # NOTE: this is an array element, in the template it is using ".._names[]"
  # but here we have to supply the name without the brackets
  # (the array is handled by the form flattening function)
  push @hidden_vars, "${name_prefix}_names";

  return @hidden_vars;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Presenter::DatePeriodAdder - presenter to add multiple date period pickers dynamically

=head1 SYNOPSIS

  use SL::Presenter::DatePeriodAdder qw(date_period_adder adder);
  my $html = date_period_adder('dateperiod');

  # in template
  [% P.date_period_adder.adder('dateperiod') %]

  # reading the entered date periods from the form
  my $date_periods = SL::Presenter::DatePeriodAdder::get_date_periods($::form, 'dateperiod');

  # getting the hidden variables for carrying over to a report
  my @hidden_vars = SL::Presenter::DatePeriodAdder::get_hidden_variables_for_report($::form, 'dateperiod');

=head1 DESCRIPTION

Renders a small UI that starts with a single date period picker and
shows a button below it to append more pickers. When the button is pressed
an AJAX request is performed to the controller action that returns a new
DatePeriod picker (using SL::Presenter::DatePeriod), which is appended
into the container. A hidden counter keeps track of how many items were
added so that IDs are generated as "prefix_2", "prefix_3" etc.

=head1 FUNCTIONS

=over 2

=item C<get_date_periods $form, $name_prefix>

Helper function to read the form fields that were created by the adder and
return an array reference of hashrefs describing the periods that contain at
least one value. Each hashref includes the entered "from" and "to" dates,
the index in the order the picker was rendered, and the unique name of the
picker. The name prefix is used to read the hidden array containing the
names of the active pickers.

Example return value for two periods:

  [
    {
      from  => '2024-01-01',
      to    => '2024-12-31',
      index => 0,
      name  => 'mydateperiod_0',
      from_dateobj => Date::Object for '2024-01-01',
      to_dateobj   => Date::Object for '2024-12-31',
    },
    {
      from  => '2025-01-01',
      to    => '2025-06-30',
      index => 1,
      name  => 'mydateperiod_1',
      from_dateobj => Date::Object for '2025-01-01',
      to_dateobj   => Date::Object for '2025-06-30',
    },
  ]

=item C<get_hidden_variables_for_report $form, $name_prefix>

Helper function returning the list of form field names that need to be
preserved when the picker data is carried over to a report. It reuses the
list of active periods from C<get_date_periods> and adds the hidden inputs
for the individual date fields as well as the array name that tracks the
period names. Use this list when populating the C<hidden_variables> array
for report generation.

=back

=cut
