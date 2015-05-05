package SL::Controller::Helper::GetModels::Sorted;

use strict;
use parent 'SL::Controller::Helper::GetModels::Base';

use Carp;
use List::MoreUtils qw(uniq);

use Data::Dumper;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(by dir specs form_data) ],
  'scalar --get_set_init' => [ qw(form_params) ],
);

sub init {
  my ($self, %specs) = @_;

  $self->set_get_models(delete $specs{get_models});
  my %model_sort_spec   = $self->get_models->manager->_sort_spec;

  if (my $default = delete $specs{_default}) {
    $self->by ($default->{by});
    $self->dir($default->{dir});
  } else {
    $self->by ($model_sort_spec{default}[0]);
    $self->dir($model_sort_spec{default}[1]);
  }

  while (my ($column, $spec) = each %specs) {
    next if $column =~ m/^[A-Z_]+$/;

    $spec = $specs{$column} = { title => $spec } if (ref($spec) || '') ne 'HASH';

    $spec->{model}        ||= $self->get_models->model;
    $spec->{model_column} ||= $column;
  }
  $self->specs(\%specs);

  $self->get_models->register_handlers(
    callback   => sub { shift; $self->_callback_handler_for_sorted(@_) },
  );

#   $::lxdebug->dump(0, "CONSPEC", \%specs);
}

sub read_params {
  my ($self, %params) = @_;

  return %{ $self->form_data } if $self->form_data;

  my %sort_params;
  my ($by, $dir) = @{ $self->form_params };
  my $source = $self->get_models->source;

  if ($source->{ $by }) {
    %sort_params = (
      sort_by  => $source->{$by},
      sort_dir => defined($source->{$dir}) ? $source->{$dir} * 1 : undef,
    );
  } elsif (!$self->by) {
    %sort_params = %params;
  } else {
    %sort_params = (
      sort_by  => $self->by,
      sort_dir => $self->dir,
    );
  }

  $self->form_data(\%sort_params);

  return %sort_params;
}

sub finalize {
  my ($self, %params) = @_;

  my %sort_params     = $self->read_params;
  my $sort_spec       = $self->specs->{ $sort_params{sort_by} };

  if (!$sort_spec) {
    no warnings 'once';
    $::lxdebug->show_backtrace(1);
    die "Unknown sort spec '$sort_params{sort_by}'";
  }

  $params{sort_by}    = "SL::DB::Manager::$sort_spec->{model}"->make_sort_string(sort_by => $sort_spec->{model_column}, sort_dir => $sort_params{sort_dir});

  %params;
}

sub set_report_generator_sort_options {
  my ($self, %params) = @_;

  $params{$_} or croak("Missing parameter '$_'") for qw(report sortable_columns);

  my %current_sort_params = $self->read_params;

  foreach my $col (@{ $params{sortable_columns} }) {
    $params{report}->{columns}->{$col}->{link} = $self->get_models->get_callback(
      sort_by  => $col,
      sort_dir => ($current_sort_params{sort_by} eq $col ? 1 - $current_sort_params{sort_dir} : $current_sort_params{sort_dir}),
    );
  }

  $params{report}->set_sort_indicator($current_sort_params{sort_by}, 1 - $current_sort_params{sort_dir});

  if ($params{report}->{export}) {
    $params{report}->{export}->{variable_list} = [ uniq(
      @{ $params{report}->{export}->{variable_list} },
      @{ $self->form_params }
    )];
  }
}

#
# private functions
#

sub _callback_handler_for_sorted {
  my ($self, %params) = @_;
  my %spec = $self->read_params;

  if ($spec{sort_by}) {
    $params{ $self->form_params->[0] } = $spec{sort_by};
    $params{ $self->form_params->[1] } = $spec{sort_dir};
  }

  # $::lxdebug->dump(0, "CB handler for sorted; params nach modif:", \%params);

  return %params;
}

sub init_form_params {
  [ qw(sort_by sort_dir) ]
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

  SL::Controller::Helper::GetModels->new(
    ...
    sorted => {
      _default => {
        by  => 'run_at',
        dir => 1,
      },
      error        => $::locale->text('Error'),
      package_name => $::locale->text('Package name'),
      run_at       => $::locale->text('Run at'),
    },
  );

In template:

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

This C<GetModels> plugin enables controllers to display a
sortable list of database models with as few lines as possible.

For this to work the controller has to provide the information which
indexes are eligible for sorting etc. through it's configuration of
C<GetModels>.

A template can then use the method C<sortable_table_header> from the layout
helper module C<L>.

This module requires that the Rose model managers use their
C<SL::DB::Helper::Sorted> helper.

=head1 OPTIONS

=over 4

=item * C<_default HASHREF>

Optional. If it exists, it is expected to contain the keys C<by> and C<dir> and
will be used to set the default sorting if nothing is found in C<source>.

Defaults to the underlying database model's default.

=item * C<form_params>

Optional. An array reference with exactly two strings that name the
indexes in C<source> in which the sort index (the first element in
the array) and sort direction (the second element in the array) are
stored.

Defaults to the values C<sort_by> and C<sort_dir> if missing.

=back

All other keys can be used for sorting. Each value to such a key can be either
a string or a hash reference containing certain elements. If the value is only
a string then such a hash reference is constructed, and the string is
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

=head1 INSTANCE FUNCTIONS

These functions are called on a C<GetModels> instance and delegating to this plugin.

=over 4

=item C<get_sort_spec>

Returns a hash containing the currently active sort parameters.

The key C<by> contains the active sort index referring to the
C<%sort_spec> given by the configuration.

The key C<dir> is either C<1> or C<0>.

=item C<get_current_sort_params>

Returns a hash reference to the sort spec structure given in the configuration
after normalization (hash reference construction, applying default parameters
etc).

=item C<set_report_generator_sort_options %params>

This function does three things with an instance of
L<SL::ReportGenerator>:

=over 4

=item 1. it sets the sort indicator,

=item 2. it sets the the links for those column headers that are
sortable and

=item 3. it adds the C<form_params> fields to the list of variables in
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

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
