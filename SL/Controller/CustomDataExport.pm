package SL::Controller::CustomDataExport;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use DBI qw(:sql_types);
use File::Temp ();
use List::UtilsBy qw(sort_by);
use POSIX qw(strftime);
use Text::CSV_XS;

use SL::DB::CustomDataExportQuery;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(rows) ],
  'scalar --get_set_init' => [ qw(query queries parameters) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('setup_javascripts');

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('custom_data_export/list', title => $::locale->text('Execute a custom report query'));
}

sub action_export {
  my ($self) = @_;

  if (!$::form->{parameters_set}) {
    $self->setup_export_action_bar;
    return $self->render('custom_data_export/export', title => t8("Execute custom report '#1'", $self->query->name));
  }

  $self->execute_query;

  if (scalar(@{ $self->rows // [] }) == 1) {
    $self->setup_empty_result_set_action_bar;
    return $self->render('custom_data_export/empty_result_set', title => t8("Execute custom report '#1'", $self->query->name));
  }

  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);

  my $report_name =  $self->query->name;
  $report_name    =~ s{[^[:word:]]+}{_}ig;
  $report_name   .=  strftime('_%Y-%m-%d_%H-%M-%S', localtime());

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'CustomDataExport',
    output_format         => 'HTML',
    top_info_text         => $self->query->name,
    title                 => $self->query->name,
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
    allow_chart_export    => 1,
    attachment_basename   => $report_name,
  );

  my %column_defs;
  foreach my $key (@{ $self->rows->[0] }) {
    $column_defs{$key} = { text => $key, sub => sub { $_[0]->{$key} } };
  }

  $report->set_columns(%column_defs);
  $report->set_column_order(@{ $self->rows->[0] });

  $report->set_export_options(qw(export id parameters_set parameters));
  $report->set_options_from_form;

  # Setup data objects (which in this case is an array of hashes).
  my @objects;
  foreach my $set_idx (1..$#{ $self->rows }) {
    my %row_set;
    foreach my $key_idx (0..$#{ $self->rows->[0] }) {
      my $key   = $self->rows->[0]->[$key_idx];
      my $value = $self->rows->[$set_idx]->[$key_idx];
      $row_set{$key} = $value;
    }
    push @objects, \%row_set;
  }

  $self->report_generator_list_objects(report  => $report,
                                       objects => \@objects,
                                       options => {
                                         action_bar_additional_submit_values => { id => $::form->{id}, },
                                       },
  );
}

#
# filters
#

sub check_auth {
  my ($self) = @_;
  $::auth->assert('custom_data_report');
  $::auth->assert($self->query->access_right) if $self->query->access_right;
}

sub setup_javascripts {
  $::request->layout->add_javascripts('kivi.Validator.js');
}

#
# helpers
#

sub init_query      { $::form->{id} ? SL::DB::CustomDataExportQuery->new(id => $::form->{id})->load : SL::DB::CustomDataExportQuery->new }
sub init_parameters { [ sort_by { lc $_->name } @{ $_[0]->query->parameters // [] } ] }

sub init_queries {
  my %rights_map     = %{ $::auth->load_rights_for_user($::form->{login}) };
  my @granted_rights = grep { $rights_map{$_} } keys %rights_map;

  return scalar SL::DB::Manager::CustomDataExportQuery->get_all_sorted(
    where => [
      or => [
        access_right => undef,
        access_right => '',
        (access_right => \@granted_rights) x !!@granted_rights,
      ],
    ],
  )
}

sub setup_export_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Execute'),
        submit    => [ '#form', { action => 'CustomDataExport/export' } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

sub setup_empty_result_set_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

sub prepare_query {
  my ($self) = @_;

  my $sql_query = $self->query->sql_query;
  my @values;

  my %values_by_name;

  foreach my $parameter (@{ $self->query->parameters // [] }) {
    my $value                           = ($::form->{parameters} // {})->{ $parameter->name };
    $values_by_name{ $parameter->name } = $parameter->parameter_type eq 'number' ? $::form->parse_amount(\%::myconfig, $value) : $value;
  }

  while ($sql_query =~ m{<\%(.+?)\%>}) {
    push @values, $values_by_name{$1};
    substr($sql_query, $-[0], $+[0] - $-[0], '?');
  }

  return ($sql_query, @values);
}

sub execute_query {
  my ($self) = @_;

  my ($sql_query, @values) = $self->prepare_query;
  my $sth                  = $self->query->db->dbh->prepare($sql_query) || $::form->dberror;
  $sth->execute(@values)                                                || $::form->dberror;

  my @names = @{ $sth->{NAME} };
  my @types = @{ $sth->{TYPE} };
  my @data  = @{ $sth->fetchall_arrayref };

  $sth->finish;

  foreach my $row (@data) {
    foreach my $col (0..$#types) {
      my $type = $types[$col];

      if ($type == SQL_NUMERIC) {
        $row->[$col] = $::form->format_amount(\%::myconfig, $row->[$col]);
      }
    }
  }

  $self->rows([
    \@names,
    @data,
  ]);
}

1;
