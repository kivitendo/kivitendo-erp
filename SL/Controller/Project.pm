package SL::Controller::Project;

use strict;

use parent qw(SL::Controller::Base);

use Clone qw(clone);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;
use SL::CVar;
use SL::DB::Customer;
use SL::DB::DeliveryOrder;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::Project;
use SL::DB::PurchaseInvoice;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(project db_args flat_filter linked_records) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_project', only => [ qw(edit update destroy) ]);

__PACKAGE__->get_models_url_params('flat_filter');
__PACKAGE__->make_paginated(
  MODEL         => 'Project',
  PAGINATE_ARGS => 'db_args',
  ONLY          => [ qw(list) ],
);

__PACKAGE__->make_sorted(
  MODEL         => 'Project',
  ONLY          => [ qw(list) ],

  DEFAULT_BY    => 'projectnumber',
  DEFAULT_DIR   => 1,

  customer      => t8('Customer'),
  description   => t8('Description'),
  projectnumber => t8('Project Number'),
  type          => t8('Type'),
);


#
# actions
#

sub action_search {
  my ($self) = @_;

  my %params;

  $params{CUSTOM_VARIABLES} = CVar->get_configs(module => 'Projects');
  ($params{CUSTOM_VARIABLES_FILTER_CODE}, $params{CUSTOM_VARIABLES_INCLUSION_CODE})
    = CVar->render_search_options(variables      => $params{CUSTOM_VARIABLES},
                                  include_prefix => 'l_',
                                  include_value  => 'Y');

  $self->render('project/search', %params);
}

sub action_list {
  my ($self) = @_;

  $self->setup_db_args_from_filter;
  $self->flat_filter({ map { $_->{key} => $_->{value} } $::form->flatten_variables('filter') });
  # $self->make_filter_summary;

  $self->prepare_report;

  my $projects = $self->get_models(%{ $self->db_args });

  $self->report_generator_list_objects(report => $self->{report}, objects => $projects);
}

sub action_new {
  my ($self) = @_;

  $self->project(SL::DB::Project->new);
  $self->display_form(title    => $::locale->text('Create a new project'),
                      callback => $::form->{callback} || $self->url_for(action => 'new'));
}

sub action_edit {
  my ($self) = @_;

  $self->linked_records([
    map  { @{ $_ } }
    grep { $_      } (
      SL::DB::Manager::Order->          get_all(where => [ globalproject_id => $self->project->id ], with_objects => [ 'customer', 'vendor' ], sort_by => 'transdate ASC'),
      SL::DB::Manager::DeliveryOrder->  get_all(where => [ globalproject_id => $self->project->id ], with_objects => [ 'customer', 'vendor' ], sort_by => 'transdate ASC'),
      SL::DB::Manager::Invoice->        get_all(where => [ globalproject_id => $self->project->id ], with_objects => [ 'customer'           ], sort_by => 'transdate ASC'),
      SL::DB::Manager::PurchaseInvoice->get_all(where => [ globalproject_id => $self->project->id ], with_objects => [             'vendor' ], sort_by => 'transdate ASC'),
    )]);

  $self->display_form(title    => $::locale->text('Edit project #1', $self->project->projectnumber),
                      callback => $::form->{callback} || $self->url_for(action => 'edit', id => $self->project->id));
}

sub action_create {
  my ($self) = @_;

  $self->project(SL::DB::Project->new);
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->project->delete; 1; }) {
    flash_later('info',  $::locale->text('The project has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The project is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'search');
}

#
# filters
#

sub check_auth {
  $::auth->assert('project_edit');
}

#
# helpers
#

sub display_form {
  my ($self, %params) = @_;

  $params{ALL_CUSTOMERS}    = SL::DB::Manager::Customer->get_all_sorted(where => [ or => [ obsolete => 0, obsolete => undef, id => $self->project->customer_id ]]);
  $params{CUSTOM_VARIABLES} = CVar->get_custom_variables(module => 'Projects', trans_id => $self->project->id);
  CVar->render_inputs(variables => $params{CUSTOM_VARIABLES}) if @{ $params{CUSTOM_VARIABLES} };

  $self->render('project/form', %params);
}

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->project->id;
  my $params = delete($::form->{project}) || { };

  delete $params->{id};
  $self->project->assign_attributes(%{ $params });

  my @errors = $self->project->validate;

  if (@errors) {
    flash('error', @errors);
    $self->display_form(title    => $is_new ? $::locale->text('Create a new project') : $::locale->text('Edit project'),
                        callback => $::form->{callback});
    return;
  }

  $self->project->save;

  CVar->save_custom_variables(
    dbh          => $self->project->db->dbh,
    module       => 'Projects',
    trans_id     => $self->project->id,
    variables    => $::form,
    always_valid => 1,
  );

  flash_later('info', $is_new ? $::locale->text('The project has been created.') : $::locale->text('The project has been saved.'));

  $self->redirect_to($::form->{callback} || (action => 'search'));
}

sub load_project {
  my ($self) = @_;
  $self->project(SL::DB::Project->new(id => $::form->{id})->load);
}

sub setup_db_args_from_filter {
  my ($self) = @_;

  $self->{filter} = {};
  my %args = parse_filter(
    $self->_pre_parse_filter($::form->{filter}, $self->{filter}),
    with_objects => [ 'customer' ],
    launder_to   => $self->{filter},
  );

  $self->db_args(\%args);
}

# unfortunately ParseFilter can't handle compount filters.
# so we clone the original filter (still need that for serializing)
# rip out the options we know an replace them with the compound options.
# ParseFilter will take care of the prefixing then.
sub _pre_parse_filter {
  my ($self, $orig_filter, $launder_to) = @_;

  return undef unless $orig_filter;

  my $filter = clone($orig_filter);

  $launder_to->{active} = delete $filter->{active};
  if ($orig_filter->{active} ne 'both') {
    push @{ $filter->{and} }, $orig_filter->{active} eq 'active' ? (active => 1) : (or => [ active => 0, active => undef ]);
  }

  $launder_to->{valid} = delete $filter->{valid};
  if ($orig_filter->{valid} ne 'both') {
    push @{ $filter->{and} }, $orig_filter->{valid} eq 'valid' ? (valid => 1) : (or => [ valid => 0, valid => undef ]);
  }

  $launder_to->{status} = delete $filter->{status};
  if ($orig_filter->{status} ne 'all') {
    push @{ $filter->{and} }, SL::DB::Manager::Project->is_not_used_filter;
  }

  return $filter;
}

sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->get_callback;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(projectnumber description customer active valid type);
  my @sortable    = qw(projectnumber description customer              type);

  my %column_defs = (
    projectnumber => { obj_link => sub { $self->url_for(action => 'edit', id => $_[0]->id, callback => $callback) } },
    description   => { obj_link => sub { $self->url_for(action => 'edit', id => $_[0]->id, callback => $callback) } },
    type          => { },
    customer      => { sub  => sub { $_[0]->customer ? $_[0]->customer->name     : '' } },
    active        => { sub  => sub { $_[0]->active   ? $::locale->text('Active') : $::locale->text('Inactive') },
                       text => $::locale->text('Active') },
    valid         => { sub  => sub { $_[0]->valid    ? $::locale->text('Valid')  : $::locale->text('Invalid')  },
                       text => $::locale->text('Valid')  },
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'Project',
    output_format         => 'HTML',
    top_info_text         => $::locale->text('Projects'),
    raw_bottom_info_text  => $self->render('project/report_bottom', { output => 0 }),
    title                 => $::locale->text('Projects'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  $self->disable_pagination if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
}

1;
