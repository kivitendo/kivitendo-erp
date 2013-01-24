package SL::Controller::Helper::Sorted;

use strict;

use Carp;
use List::MoreUtils qw(uniq);

use Exporter qw(import);
our @EXPORT = qw(make_sorted get_sort_spec get_current_sort_params set_report_generator_sort_options
                 _save_current_sort_params _get_models_handler_for_sorted _callback_handler_for_sorted);

use constant PRIV => '__sortedhelperpriv';

my %controller_sort_spec;

sub make_sorted {
  my ($class, %specs) = @_;

  $specs{MODEL} ||=  $class->controller_name;
  $specs{MODEL}   =~ s{ ^ SL::DB:: (?: .* :: )? }{}x;

  while (my ($column, $spec) = each %specs) {
    next if $column =~ m/^[A-Z_]+$/;

    $spec = $specs{$column} = { title => $spec } if (ref($spec) || '') ne 'HASH';

    $spec->{model}        ||= $specs{MODEL};
    $spec->{model_column} ||= $column;
  }

  my %model_sort_spec   = "SL::DB::Manager::$specs{MODEL}"->_sort_spec;
  $specs{DEFAULT_DIR}   = $specs{DEFAULT_DIR} ? 1 : defined($specs{DEFAULT_DIR}) ? $specs{DEFAULT_DIR} * 1 : $model_sort_spec{default}->[1];
  $specs{DEFAULT_BY}  ||= $model_sort_spec{default}->[0];
  $specs{FORM_PARAMS} ||= [ qw(sort_by sort_dir) ];
  $specs{ONLY}        ||= [];
  $specs{ONLY}          = [ $specs{ONLY} ] if !ref $specs{ONLY};

  $controller_sort_spec{$class} = \%specs;

  my %hook_params = @{ $specs{ONLY} } ? ( only => $specs{ONLY} ) : ();
  $class->run_before('_save_current_sort_params', %hook_params);

  SL::Controller::Helper::GetModels::register_get_models_handlers(
    $class,
    callback   => '_callback_handler_for_sorted',
    get_models => '_get_models_handler_for_sorted',
    ONLY       => $specs{ONLY},
  );

  # $::lxdebug->dump(0, "CONSPEC", \%specs);
}

sub get_sort_spec {
  my ($class_or_self) = @_;

  return $controller_sort_spec{ref($class_or_self) || $class_or_self};
}

sub get_current_sort_params {
  my ($self, %params) = @_;

  my $sort_spec = $self->get_sort_spec;

  if (!$params{sort_by}) {
    my $priv          = $self->{PRIV()} || {};
    $params{sort_by}  = $priv->{by};
    $params{sort_dir} = $priv->{dir};
  }

  my $by          = $params{sort_by} || $sort_spec->{DEFAULT_BY};
  my %sort_params = (
    dir => defined($params{sort_dir}) ? $params{sort_dir} * 1 : $sort_spec->{DEFAULT_DIR},
    by  => $sort_spec->{$by} ? $by : $sort_spec->{DEFAULT_BY},
  );

  return %sort_params;
}

sub set_report_generator_sort_options {
  my ($self, %params) = @_;

  $params{$_} or croak("Missing parameter '$_'") for qw(report sortable_columns);

  my %current_sort_params = $self->get_current_sort_params;

  foreach my $col (@{ $params{sortable_columns} }) {
    $params{report}->{columns}->{$col}->{link} = $self->get_callback(
      sort_by  => $col,
      sort_dir => ($current_sort_params{by} eq $col ? 1 - $current_sort_params{dir} : $current_sort_params{dir}),
    );
  }

  $params{report}->set_sort_indicator($current_sort_params{by}, 1 - $current_sort_params{dir});

  if ($params{report}->{export}) {
    $params{report}->{export}->{variable_list} = [ uniq(
      @{ $params{report}->{export}->{variable_list} },
      @{ $self->get_sort_spec->{FORM_PARAMS} }
    )];
  }
}

#
# private functions
#

sub _save_current_sort_params {
  my ($self)      = @_;

  my $sort_spec   = $self->get_sort_spec;
  my $dir_idx     = $sort_spec->{FORM_PARAMS}->[1];
  $self->{PRIV()} = {
    by            =>   $::form->{ $sort_spec->{FORM_PARAMS}->[0] },
    dir           => defined($::form->{$dir_idx}) ? $::form->{$dir_idx} * 1 : undef,
  };

  # $::lxdebug->message(0, "saving current sort params to " . $self->{PRIV()}->{by} . ' / ' . $self->{PRIV()}->{dir});
}

sub _callback_handler_for_sorted {
  my ($self, %params) = @_;

  my $priv = $self->{PRIV()} || {};
  if ($priv->{by}) {
    my $sort_spec                             = $self->get_sort_spec;
    $params{ $sort_spec->{FORM_PARAMS}->[0] } = $priv->{by};
    $params{ $sort_spec->{FORM_PARAMS}->[1] } = $priv->{dir};
  }

  # $::lxdebug->dump(0, "CB handler for sorted; params nach modif:", \%params);

  return %params;
}

sub _get_models_handler_for_sorted {
  my ($self, %params) = @_;

  my %sort_params     = $self->get_current_sort_params;
  my $sort_spec       = $self->get_sort_spec->{ $sort_params{by} };

  $params{model}      = $sort_spec->{model};
  $params{sort_by}    = "SL::DB::Manager::$params{model}"->make_sort_string(sort_by => $sort_spec->{model_column}, sort_dir => $sort_params{dir});

  # $::lxdebug->dump(0, "GM handler for sorted; params nach modif:", \%params);

  return %params;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::Sorted - A helper for semi-automatic handling
of sorting lists of database models in a controller

=head1 SYNOPSIS

In a controller:

  use SL::Controller::Helper::GetModels;
  use SL::Controller::Helper::Sorted;

  __PACKAGE__->make_sorted(
    DEFAULT_BY   => 'run_at',
    DEFAULT_DIR  => 1,
    MODEL        => 'BackgroundJobHistory',
    ONLY         => [ qw(list) ],

    error        => $::locale->text('Error'),
    package_name => $::locale->text('Package name'),
    run_at       => $::locale->text('Run at'),
  );

  sub action_list {
    my ($self) = @_;

    my $sorted_models = $self->get_models;
    $self->render('controller/list', ENTRIES => $sorted_models);
  }

In said template:

  [% USE L %]

  <table>
   <tr>
    <th>[% L.sortable_table_header('package_name') %]</th>
    <th>[% L.sortable_table_header('run_at') %]</th>
    <th>[% L.sortable_table_header('error') %]</th>
   </tr>

   [% FOREACH entry = ENTRIES %]
    <tr>
     <td>[% HTML.escape(entry.package_name) %]</td>
     <td>[% HTML.escape(entry.run_at) %]</td>
     <td>[% HTML.escape(entry.error) %]</td>
    </tr>
   [% END %]
  </table>

=head1 OVERVIEW

This specialized helper module enables controllers to display a
sortable list of database models with as few lines as possible.

For this to work the controller has to provide the information which
indexes are eligible for sorting etc. by a call to L<make_sorted> at
compile time.

The underlying functionality that enables the use of more than just
the sort helper is provided by the controller helper C<GetModels>. It
provides mechanisms for helpers like this one to hook into certain
calls made by the controller (C<get_callback> and C<get_models>) so
that the specialized helpers can inject their parameters into the
calls to e.g. C<SL::DB::Manager::SomeModel::get_all>.

A template on the other hand can use the method
C<sortable_table_header> from the layout helper module C<L>.

This module requires that the Rose model managers use their C<Sorted>
helper.

The C<Sorted> helper hooks into the controller call to the action via
a C<run_before> hook. This is done so that it can remember the sort
parameters that were used in the current view.

=head1 PACKAGE FUNCTIONS

=over 4

=item C<make_sorted %sort_spec>

This function must be called by a controller at compile time. It is
uesd to set the various parameters required for this helper to do its
magic.

There are two sorts of keys in the hash C<%sort_spec>. The first kind
is written in all upper-case. Those parameters are control
parameters. The second kind are all lower-case and represent indexes
that can be used for sorting (similar to database column names). The
second kind are also the indexes you use in a template when calling
C<[% L.sorted_table_header(...) %]>.

Control parameters include the following:

=over 4

=item * C<MODEL>

Optional. A string: the name of the Rose database model that is used
as a default in certain cases. If this parameter is missing then it is
derived from the controller's package (e.g. for the controller
C<SL::Controller::BackgroundJobHistory> the C<MODEL> would default to
C<BackgroundJobHistory>).

=item * C<DEFAULT_BY>

Optional. A string: the index to sort by if the user hasn't clicked on
any column yet (meaning: if the C<$::form> parameters for sorting do
not contain a valid index).

Defaults to the underlying database model's default sort column name.

=item * C<DEFAULT_DIR>

Optional. Default sort direction (ascending for trueish values,
descrending for falsish values).

Defaults to the underlying database model's default sort direction.

=item * C<FORM_PARAMS>

Optional. An array reference with exactly two strings that name the
indexes in C<$::form> in which the sort index (the first element in
the array) and sort direction (the second element in the array) are
stored.

Defaults to the values C<sort_by> and C<sort_dir> if missing.

=item * C<ONLY>

Optional. An array reference containing a list of action names for
which the sort parameters should be saved. If missing or empty then
all actions invoked on the controller are monitored.

=back

All keys that are written in all lower-case name indexes that can be
used for sorting. Each value to such a key can be either a string or a
hash reference containing certain elements. If the value is only a
string then such a hash reference is constructed, and the string is
used as the value for the C<title> key.

These possible elements are:

=over 4

=item * C<title>

Required. A user-displayable title to be used by functions like the
layout helper's C<sortable_table_header>. Does not have a default
value.

Note that this string must be the untranslated English version of the
string. The titles will be translated whenever they're requested.

=item * C<model>

Optional. The name of a Rose database model this sort index refers
to. If missing then the value of C<$sort_spec{MODEL}> is used.

=item * C<model_column>

Optional. The name of the Rose database model column this sort index
refers to. It must be one of the columns named by the model's
C<Sorted> helper (not to be confused with the controller's C<Sorted>
helper!).

If missing it defaults to the key in C<%sort_spec> for which this hash
reference is the value.

=back

=back

=head1 INSTANCE FUNCTIONS

These functions are called on a controller instance.

=over 4

=item C<get_sort_spec>

Returns a hash containing the currently active sort parameters.

The key C<by> contains the active sort index referring to the
C<%sort_spec> given to L<make_sorted>.

The key C<dir> is either C<1> or C<0>.

=item C<get_current_sort_params>

Returns a hash reference to the sort spec structure given in the call
to L<make_sorted> after normalization (hash reference construction,
applying default parameters etc).

=item C<set_report_generator_sort_options %params>

This function does three things with an instance of
L<SL::ReportGenerator>:

=over 4

=item 1. it sets the sort indicator,

=item 2. it sets the the links for those column headers that are
sortable and

=item 3. it adds the C<FORM_PARAMS> fields to the list of variables in
the report generator's export options.

=back

The report generator instance must be passed as the parameter
C<report>. The parameter C<sortable_columns> must be an array
reference of column names that are sortable.

The report generator instance must already have its columns and export
options set via calls to its L<SL::ReportGenerator::set_columns> and
L<SL::ReportGenerator::set_export_options> functions.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
