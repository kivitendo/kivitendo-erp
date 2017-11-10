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

  $self->render('custom_data_export/list', title => $::locale->text('Execute a custom data export query'));
}

sub action_export {
  my ($self) = @_;

  if (!$::form->{format}) {
    $self->setup_export_action_bar;
    return $self->render('custom_data_export/export', title => t8("Execute custom data export '#1'", $self->query->name));
  }

  $self->execute_query;

  if (scalar(@{ $self->rows // [] }) == 1) {
    $self->setup_empty_result_set_action_bar;
    return $self->render('custom_data_export/empty_result_set', title => t8("Execute custom data export '#1'", $self->query->name));
  }


  my $method = "export_as_" . $::form->{format};
  $self->$method;
}

#
# filters
#

sub check_auth {
  my ($self) = @_;
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
        t8('Export'),
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

sub export_as_csv {
  my ($self) = @_;

  my $csv = Text::CSV_XS->new({
    binary   => 1,
    sep_char => ';',
    eol      => "\n",
  });

  my ($file_handle, $file_name) = File::Temp::tempfile;

  binmode $file_handle, ":encoding(utf8)";

  $csv->print($file_handle, $_) for @{ $self->rows };

  $file_handle->close;

  my $report_name =  $self->query->name;
  $report_name    =~ s{[^[:word:]]+}{_}ig;
  $report_name   .=  strftime('_%Y-%m-%d_%H-%M-%S.csv', localtime());

  $self->send_file(
    $file_name,
    content_type => 'text/csv',
    name         => $report_name,
  );
}

1;
