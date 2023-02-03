package SL::Presenter::DatePeriod;

use strict;

use Exporter qw(import);
our @EXPORT_OK = qw(
  date_period_picker
  get_dialog_defaults_from_report_generator
  populate_hidden_variables
);

use SL::Presenter::Tag qw(name_to_id);

sub date_period_picker {
  my ($name, $value_from, $value_to, %params) = @_;

  my $id = name_to_id($name);
  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'date_period_picker';

  my $dialog_defaults = {
    year => $params{dialog_defaults}->{year} // DateTime->today->year,
    type => $params{dialog_defaults}->{type} // 'yearly',
    quarter => $params{dialog_defaults}->{quarter} // 'A',
    month => $params{dialog_defaults}->{month} // '1',
  };

  my $html = SL::Presenter->get->render(
    'presenter/date_period/date_period_picker',
    id => $id,
    classes => \@classes,
    defaults => {
      report_period_from_date => $value_from || '',
      report_period_to_date => $value_to || '',
      dialog => $dialog_defaults
    },
    years_list => get_years(),
    months_list => get_months(),
  );
  $::request->layout->add_javascripts('kivi.Presenter.DatePeriodPicker.js');

  return $html;
}

### convenience functions

sub get_dialog_defaults_from_report_generator {
  my ($name) = @_;

  my $id = name_to_id($name);

  my %fallback_dateperiod_dialog = (
    year => DateTime->today->year,
    type => 'yearly',
    quarter => 'A',
    month => '1',
  );
  my %defaults_dialog;
  for (keys %fallback_dateperiod_dialog) {
    $defaults_dialog{$_} = $::form->{'report_generator_hidden_' . $id . '_selected_preset_' . $_} //
                            $fallback_dateperiod_dialog{$_};
  }
  return \%defaults_dialog;
}

sub populate_hidden_variables {
  my ($name, $hidden_variables_ref) = @_;

  my $id = name_to_id($name);

  my @vars = qw(
    _from_date
    _to_date
    _selected_preset_year
    _selected_preset_type
    _selected_preset_quarter
    _selected_preset_month
  );

  push @{ $hidden_variables_ref }, map { $id . $_ } @vars;
}

### helper

sub get_months {
  my $dt = DateTime->now;
  my $months = $dt->{locale}->{locale_data}->{month_format_wide};
  my $i = 0;
  [ map { $i++; [ $i, $::locale->text($_) ] } @{ $months } ];
}

sub get_years {
  my $current = DateTime->today->year;
  [ map { [ $current - $_, $current - $_, ] } (0..39) ];
}

sub picker { goto &date_period_picker }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Presenter::DatePeriod - Date period stuff

=head1 SYNOPSIS

  # use in perl code
  use SL::Presenter::DatePeriod qw(date_period_picker);
  my $html   = date_period_picker('my-picker-id', '', '');
  my $html   = date_period_picker('my-other-picker-id', $from_date, $to_date);

  # use in template
  [% P.date_period.picker('my-picker-id', '', '') %]
  [% P.date_period.picker('my-other-picker-id',
                            defaults.from_date,
                            defaults.to_date,
                            dialog_defaults => defaults.dialog) %]

see also L<SL::Presenter>

=head1 DATE PERIOD PICKER UI DESCRIPTION

Two date input fields are shown: 'From' and 'To', to select a date period.

Additionally a button is shown: 'Select from preset'.

When clicked it shows a dialog that allows the selection of a date period
from sensible presets.

=over 2

=item Dialog:

The dialog shows a select 'Year', containing the current year plus years up
to forty years back.

A period is selected with a radio button, that is either 'yearly' (default),
'quarterly' or 'monthly'.

For quarterly and monthly there is a select shown containing the respective
values.

=back

=head1 FUNCTIONS

=over 2

=item C<date_period_picker $name, $value_from, $value_to, %params>

Renders a date period picker with preset dialog.

C<$name> should be a unique name. It is converted to an id for the main
element. This id is also used as a prefix for all sub-elements that need an id.

B<Important:> The selected dates are available from the form elements

C<id _ '_from_date'> and C<id _ '_to_date'>.

In above example this would be C<'my-picker-id_from_date'> and
C<'my-picker-id_to_date'>.

C<$value_from> and C<$value_to> are used as preset values for the respective
date fields. This may be useful to keep entered value between page switches.

C<$params> Classes in C<class> are forwarded to the main element.

If you want to keep the selection over multiple requests this has to be handled
in the controller.

C<$params> can therefor contain a hash called C<dialog_defaults> with the
key/values:

  year => DateTime->today->year,  # numeric year
  type => 'yearly',               # the radio button selection:
                                  # 'yearly', 'monthly', 'quarterly'
  quarter => 'A',                 # the quarter as a letter code:
                                  # 'A', 'B', 'C', 'D' A being 1st quarter etc.
  month => '1',                   # numeric month

The values will be used to pre-select the dialog fields.

These values are also set into some hidden fields with the id in the format
e.g.: C<id _ '_selected_preset_year'>.

Convenience functions to handle report generator hidden variables are provided.
E.g.:

  use SL::Presenter::DatePeriod qw(get_dialog_defaults_from_report_generator
                                    populate_hidden_variables);

  # use values from form, then report generator form, then fallback
  my %fallback = (
    dateperiod_from_date => '',
    dateperiod_to_date => '',
    # other fields e.g.:
    # chart_id      => '',
  );
  my %defaults;
  for (keys %fallback) {
    $defaults{$_} = $::form->{$_} // $::form->{'report_generator_hidden_' . $_} // $fallback{$_};
  }

  # set dialog defaults
  $defaults{dialog} = get_dialog_defaults_from_report_generator('dateperiod');

  # set hidden fields for the report generator
  my @hidden_variables = qw(chart_id);    # e.g.
  populate_hidden_variables('dateperiod', \@hidden_variables);


=item C<get_dialog_defaults_from_report_generator $name>

Convenience function to get the dialog defaults from hidden report generator
fields. (Use in controller.)

C<$name> name of the date picker.

=item C<populate_hidden_variables $name $hidden_variables_ref>

Convenience function Add hidden variables to report a generator.
(Use in controller.)

C<$name> name of the date picker.

C<$hidden_variables_ref> reference to the hidden variable array.

=back

=head1 USE / MOTIVATION / GOAL

Use date_period_picker when you want to select a date period with preset
dialog.

Planned use: ListTransactions report settings view (new, replacement for
ca/list).

Possible uses in report settings views for:

  - rp/erfolgsrechnung (swiss)
  - rp/trial_balance
  - Inventory/stock_usage

And possibly more.

Current implementations for report periods repeat a lot of template and
perl code in different places. Hopefully this can be reduced.

While this UI may require slightly more clicks than previous / current
implementations, the interface is much more concise. It is easier on the eyes
and fits better into the new design 4.0.

=head1 LIMITATIONS

If multiple date_period_picker elements were to be used on the same page the
handling of hidden variables becomes ugly.

  my @hidden_variables = qw(
    dateperiod_from_date
    dateperiod_to_date
    dateperiod_selected_preset_year
    dateperiod_selected_preset_type
    # ... etc.
  );

Convenience functions are provided to help handle this. Currently i don't see
another way of handling this.

=head1 BUGS

None atm :)

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>

=cut
