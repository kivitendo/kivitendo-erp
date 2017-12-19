package SL::Presenter::Chart;

use strict;

use SL::DB::Chart;

use Exporter qw(import);
our @EXPORT_OK = qw(chart_picker chart);

use Carp;
use Data::Dumper;
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag name_to_id html_tag);

sub chart {
  my ($chart, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="am.pl?action=edit_account&id=' . escape($chart->id) . '">',
    escape($chart->accno),
    $params{no_link} ? '' : '</a>',
  );
  is_escaped($text);
}

sub chart_picker {
  my ($name, $value, %params) = @_;

  $value = SL::DB::Manager::Chart->find_by(id => $value) if $value && !ref $value;
  my $id = delete($params{id}) || name_to_id($name);
  my $fat_set_item = delete $params{fat_set_item};

  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'chart_autocomplete';
  push @classes, 'chartpicker_fat_set_item' if $fat_set_item;

  my $ret =
    input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id) .
    join('', map { $params{$_} ? input_tag("", delete $params{$_}, id => "${id}_${_}", type => 'hidden') : '' } qw(type category choose booked)) .
    input_tag("", (ref $value && $value->can('displayable_name')) ? $value->displayable_name : '', id => "${id}_name", %params);

  $::request->layout->add_javascripts('autocomplete_chart.js');
  $::request->presenter->need_reinit_widgets($id);

  html_tag('span', $ret, class => 'chart_picker');
}

sub picker { goto &chart_picker }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Presenter::Chart - Chart related presenter stuff

=head1 SYNOPSIS

  # Create an html link for editing/opening a chart
  my $object = SL::DB::Manager::Chart->get_first;
  my $html   = SL::Presenter::Chart::chart($object, display => 'inline');

see also L<SL::Presenter>

=head1 DESCRIPTION

see L<SL::Presenter>

=head1 FUNCTIONS

=over 2

=item C<chart, $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the chart object C<$object>

C<%params> can include:

=over 4

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the chart's name linked
to the corresponding 'edit' action.

=back

=back

=over 2

=item C<chart_picker $name, $value, %params>

All-in-one picker widget for charts. The code was originally copied and adapted
from the part picker. The name will be both id and name of the resulting hidden
C<id> input field (but the ID can be overwritten with C<$params{id}>).

An additional dummy input will be generated which is used to find
chart. For a detailed description of its behaviour, see section
C<CHART PICKER SPECIFICATION>.

For some examples of usage see the test page at controller.pl?action=Chart/test_page

C<$value> can be a chart id or a C<Rose::DB:Object> instance.

C<%params> can include:

=over 4

=item * category

If C<%params> contains C<category> only charts of this category will be
available for selection (in the autocompletion and in the popup).

You may comma separate multiple categories, e.g C<A,Q,L>.

In SL::DB::Manager::Chart there is also a filter called C<selected_category>,
which filters the possible charts according to the category checkboxes the user
selects in the popup window. This filter may further restrict the results of
the filter category, but the user is not able to "break out of" the limits
defined by C<category>. In fact if the categories are restricted by C<category>
the popup template should only show checkboxes for those categories.

=item * type

If C<%params> contains C<type> only charts of this type will be used for
autocompletion, i.e. the selection is filtered. You may comma separate multiple
types.

Type is usually a filter for link: C<AR,AR_paid>

Type can also be a specially defined type: C<guv>, C<balance>, C<bank>

See the type filter in SL::DB::Manager::Chart.

=item * choose

If C<%params> is passed with choose=1 the input of the filter field in the
popup window is cleared. This is useful if a chart was already selected and we
want to choose a new chart and immediately see all options.

=item * fat_set_item

If C<%params> is passed with fat_set_item=1 the contents of the selected chart
object (the elements of the database chart table) are passed back via JSON into
the item object. There is an example on the test page.

Without fat_set_item only the variables id and name (displayable name) are
available.

=back

C<chart_picker> will register its javascript for inclusion in the next header
rendering. If you write a standard controller that only calls C<render> once, it
will just work.  In case the header is generated in a different render call
(multiple blocks, ajax, old C<bin/mozilla> style controllers) you need to
include C<js/autocomplete_chart.js> yourself.

=back

=head1 POPUP LAYER

For users that don't regularly do bookkeeping and haven't memorised all the
account numbers and names there are some filter options inside the popup window
to quickly narrow down the possible matches. You can filter by

=over 4

=item * chart accno or description, inside the input field

=item * accounts that have already been booked

=item * by category (AIELQC)

By selecting category checkboxes the list of available charts can be
restricted. If all checkboxes are unchecked all possible charts are shown.

=back

There are two views in the list of accounts. By default all possible accounts are shown as a long list.

But you can also show more information, in this case the resulting list is automatically paginated:

=over 4

=item * the balance of the account (as determined by SL::DB::Chart get_balance, which checks for user rights)

=item * the category

=item * the invoice date of the last transaction (may lie in the future)

=back

The partpicker also has two views, but whereas the compact block view of the
partpicker allows part boxes to be aligned in two columns, the chartpicker
block view still only shows one chart per row, because there is more
information and the account names can be quite long. This behaviour is
determined by css, however, and could be changed (div.cpc_block).  The downside
of this is that you have to scroll the window to reach the pagination controls.

The default view of the display logic is to use block view, so we don't have to
pass any parameters in the pagination GET. However, the default view for the
user is the list view, so the popup window is opened with the "Hide additional
information" select box already ticked.

=head1 CHART PICKER SPECIFICATION

The following list of design goals were applied:

=over 4

=item *

Charts should not be perceived by the user as distinct inputs of chart number and
description but as a single object

=item *

Easy to use without documentation for novice users

=item *

Fast to use with keyboard for experienced users

=item *

Possible to use without any keyboard interaction for mouse (or touchscreen)
users

=item *

Must not leave the current page in event of ambiguity (cf. current select_item
mechanism)

=item *

Should not require a feedback/check loop in the common case

=item *

Should not be constrained to exact matches

=back

The implementation consists of the following parts which will be referenced later:

=over 4

=item 1

A hidden input (id input), used to hold the id of the selected part. The only
input that gets submitted

=item 2

An input (dummy input) containing a description of the currently selected chart,
also used by the user to search for charts

=item 3

A jquery.autocomplete mechanism attached to the dummy field

=item 4

A popup layer for both feedback and input of additional data in case of
ambiguity.

=item 5

An internal status of the chart picker, indicating whether id input and dummy
input are consistent. After leaving the dummy input the chart picker must
place itself in a consistent status.

=item 6

A clickable icon (popup trigger) attached to the dummy input, which triggers the popup layer.

=back

=head1 BUGS

None atm :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

G. Richardson E<lt>information@kivitendo-premium.deE<gt>

=cut
