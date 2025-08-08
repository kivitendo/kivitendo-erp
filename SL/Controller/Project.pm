package SL::Controller::Project;

use strict;

use parent qw(SL::Controller::Base);

use Clone qw(clone);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;
use SL::CVar;
use SL::DB::Customer;
use SL::DB::DeliveryOrder;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::Project;
use SL::DB::ProjectType;
use SL::DB::ProjectStatus;
use SL::DB::PurchaseInvoice;
use SL::DB::ProjectType;
use SL::Helper::Flash;
use SL::Locale::String;

use Data::Dumper;
use JSON;
use Rose::DB::Object::Helpers qw(as_tree);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(project) ],
 'scalar --get_set_init' => [ qw(models customers project_types project_statuses projects linked_records employees may_edit_invoice_permissions
                                 cvar_configs includeable_cvar_configs include_cvars) ],
);

__PACKAGE__->run_before('check_auth',   except => [ qw(ajax_autocomplete) ]);
__PACKAGE__->run_before('load_project', only   => [ qw(edit update destroy) ]);
__PACKAGE__->run_before('use_multiselect_js', only => [ qw(new create edit update) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->setup_list_action_bar;

  $self->make_filter_summary;

  $self->prepare_report;

  $self->report_generator_list_objects(report => $self->{report}, objects => $self->models->get);
}

sub action_new {
  my ($self) = @_;

  $self->project(SL::DB::Project->new);
  $self->display_form(title    => $::locale->text('Create a new project'),
                      callback => $::form->{callback} || $self->url_for(action => 'list'));
}

sub action_edit {
  my ($self) = @_;

  $self->display_form(title    => $::locale->text('Edit project #1', $self->project->projectnumber),
                      callback => $::form->{callback} || $self->url_for(action => 'list'));
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

  $self->redirect_to(action => 'list');
}

sub action_ajax_autocomplete {
  my ($self, %params) = @_;

  $::form->{filter}{'all:substr:multi::ilike'} =~ s{[\(\)]+}{}g;

  # if someone types something, and hits enter, assume he entered the full name.
  # if something matches, treat that as the sole match
  # since we need a second get models instance with different filters for that,
  # we only modify the original filter temporarily in place
  if ($::form->{prefer_exact}) {
    local $::form->{filter}{'all::ilike'} = delete local $::form->{filter}{'all:substr:multi::ilike'};
    # active and valid filters are use as they are

    my $exact_models = SL::Controller::Helper::GetModels->new(
      controller   => $self,
      sorted       => 0,
      paginated    => { per_page => 2 },
      with_objects => [ 'customer', 'project_status', 'project_type' ],
    );
    my $exact_matches;
    if (1 == scalar @{ $exact_matches = $exact_models->get }) {
      $self->project($exact_matches);
    }
  }

  $::form->{sort_by} = 'customer_and_description';

  my $description_style = ($::form->{description_style} =~ m{both|number|description|full})
                        ? $::form->{description_style}
                        : 'full';

  my @hashes = map {
   +{
     value         => $_->full_description(style => $description_style),
     label         => $_->full_description(style => $description_style),
     id            => $_->id,
     projectnumber => $_->projectnumber,
     description   => $_->description,
     cvars         => { map { ($_->config->name => { value => $_->value_as_text, is_valid => $_->is_valid }) } @{ $_->cvars_by_config } },
    }
  } @{ $self->projects }; # neato: if exact match triggers we don't even need the init_projects

  $self->render(\ SL::JSON::to_json(\@hashes), { layout => 0, type => 'json', process => 0 });
}

sub action_test_page {
  $_[0]->render('project/test_page');
}

sub action_project_picker_search {
  $_[0]->render('project/project_picker_search', { layout => 0 });
}

sub action_project_picker_result {
  $_[0]->render('project/_project_picker_result', { layout => 0 });
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

sub init_project_statuses { SL::DB::Manager::ProjectStatus->get_all_sorted }
sub init_project_types    { SL::DB::Manager::ProjectType->get_all_sorted   }
sub init_employees        { SL::DB::Manager::Employee->get_all_sorted   }
sub init_may_edit_invoice_permissions { $::auth->assert('project_edit_view_invoices_permission', 1) }
sub init_cvar_configs                 { SL::DB::Manager::CustomVariableConfig->get_all_sorted(where => [ module => 'Projects' ]) }
sub init_includeable_cvar_configs     { [ grep { $_->includeable } @{ $_[0]->cvar_configs } ] };

sub init_include_cvars {
  my ($self) = @_;
  return { map { ($_->name => $::form->{"include_cvars_" . $_->name}) }       @{ $self->cvar_configs } } if $::form->{_include_cvars_from_form};
  return { map { ($_->name => ($_->includeable && $_->included_by_default)) } @{ $self->cvar_configs } };
}

sub init_linked_records {
  my ($self) = @_;
  return [
    map  { @{ $_ } }
    grep { $_      } (
      SL::DB::Manager::Invoice->        get_all(where        => [ invoice => 1, or => [ globalproject_id => $self->project->id, 'invoiceitems.project_id' => $self->project->id ] ],
                                                with_objects => [ 'invoiceitems', 'customer' ],
                                                distinct     => [ 'customer' ],
                                                sort_by       => 'transdate ASC'),
      SL::DB::Manager::Invoice->        get_all(where        => [ invoice => 0, or => [ globalproject_id => $self->project->id, 'transactions.project_id' => $self->project->id ] ],
                                                with_objects => [ 'transactions', 'customer' ],
                                                distinct     => [ 'customer' ],
                                                sort_by       => 'transdate ASC'),
      SL::DB::Manager::PurchaseInvoice->get_all(where => [ invoice => 1,
                                                           or => [ globalproject_id => $self->project->id, 'invoiceitems.project_id' => $self->project->id ]
                                                         ],
                                                with_objects => [ 'invoiceitems', 'vendor' ],
                                                distinct     => [ 'customer' ],
                                                sort_by => 'transdate ASC'),
      SL::DB::Manager::PurchaseInvoice->get_all(where => [ invoice => 0,
                                                           or => [ globalproject_id => $self->project->id, 'transactions.project_id' => $self->project->id ]
                                                         ],
                                                with_objects => [ 'transactions', 'vendor' ],
                                                distinct     => [ 'customer' ],
                                                sort_by => 'transdate ASC'),
      SL::DB::Manager::GLTransaction->  get_all(where => [ 'transactions.project_id' => $self->project->id ],
                                                with_objects => [ 'transactions' ],
                                                distinct     => 1,
                                                sort_by => 'transdate ASC'),
      SL::DB::Manager::Order->          get_all(where => [ or => [ globalproject_id => $self->project->id, 'orderitems.project_id' => $self->project->id ] ],
                                                with_objects => [ 'orderitems', 'customer', 'vendor' ],
                                                distinct => [ 'customer', 'vendor' ],
                                                sort_by => 'transdate ASC' ),
      SL::DB::Manager::DeliveryOrder->  get_all(where => [ or => [ globalproject_id => $self->project->id, 'orderitems.project_id' => $self->project->id ] ],
                                                with_objects => [ 'orderitems', 'customer', 'vendor' ],
                                                distinct => [ 'customer', 'vendor' ],
                                                sort_by => 'transdate ASC'),
    )];
}


sub init_projects {
  if ($::form->{no_paginate}) {
    $_[0]->models->disable_plugin('paginated');
  }

  $_[0]->models->get;
}

sub init_customers {
  my ($self)      = @_;
  my @customer_id = $self->project && $self->project->customer_id ? (id => $self->project->customer_id) : ();

  return SL::DB::Manager::Customer->get_all_sorted(where => [ or => [ obsolete => 0, obsolete => undef, @customer_id ]]);
}

sub use_multiselect_js {
  $::request->layout->use_javascript("${_}.js") for qw(jquery.selectboxes jquery.multiselect2side);
}

sub display_form {
  my ($self, %params) = @_;

  $params{CUSTOM_VARIABLES}  = CVar->get_custom_variables(module => 'Projects', trans_id => $self->project->id);

  if ($params{keep_cvars}) {
    for my $cvar (@{ $params{CUSTOM_VARIABLES} }) {
      $cvar->{value} = $::form->{"cvar_$cvar->{name}"} if $::form->{"cvar_$cvar->{name}"};
    }
  }

  CVar->render_inputs(variables => $params{CUSTOM_VARIABLES}) if @{ $params{CUSTOM_VARIABLES} };

  $::request->layout->use_javascript("$_.js") for qw(kivi.File ckeditor5/ckeditor ckeditor5/translations/de);
  $self->setup_edit_action_bar(callback => $params{callback});

  $self->render('project/form', %params);
}

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->project->id;
  my $params = delete($::form->{project}) || { };

  if (!$self->may_edit_invoice_permissions) {
    delete $params->{employee_invoice_permissions};
  } elsif (!$params->{employee_invoice_permissions}) {
    $params->{employee_invoice_permissions} = [];
  }

  delete $params->{id};
  $self->project->assign_attributes(%{ $params });

  my @errors = $self->project->validate;

  if (@errors) {
    flash('error', $_) for @errors;
    $self->display_form(title    => $is_new ? $::locale->text('Create a new project') : $::locale->text('Edit project'),
                        callback => $::form->{callback},
                        keep_cvars => 1);
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


sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->models->get_callback;

  my $report       = SL::ReportGenerator->new(\%::myconfig, $::form);
  $report->{title} = t8('Projects');
  $self->{report}  = $report;

  my @columns     = qw(project_status customer projectnumber description active valid project_type);
  my @sortable    = qw(projectnumber description customer              project_type project_status);

  my %column_defs = (
    projectnumber => { obj_link => sub { $self->url_for(action => 'edit', id => $_[0]->id, callback => $callback) } },
    description   => { obj_link => sub { $self->url_for(action => 'edit', id => $_[0]->id, callback => $callback) } },
    project_type  => { sub  => sub { $_[0]->project_type->description } },
    project_status => { sub  => sub { $_[0]->project_status->description }, text => t8('Status') },
    customer      => { sub       => sub { !$_[0]->customer_id ? '' : $_[0]->customer->name },
                       raw_data  => sub { !$_[0]->customer_id ? '' : $_[0]->customer->presenter->customer(display => 'table-cell', callback => $callback) } },
    active        => { sub  => sub { $_[0]->active   ? $::locale->text('Active') : $::locale->text('Inactive') },
                       text => $::locale->text('Active') },
    valid         => { sub  => sub { $_[0]->valid    ? $::locale->text('Valid')  : $::locale->text('Invalid')  },
                       text => $::locale->text('Valid')  },
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->models->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  # Custom variables
  my %cvar_column_defs = map {
    my $cfg = $_;
    (('cvar_' . $cfg->name) => {
      sub     => sub { my $var = $_[0]->cvar_by_name($cfg->name); $var ? $var->value_as_text : '' },
      text    => $cfg->description,
      visible => $self->include_cvars->{ $cfg->name } ? 1 : 0,
    })
  } @{ $self->includeable_cvar_configs };

  push @columns, map { 'cvar_' . $_->name } @{ $self->includeable_cvar_configs };
  %column_defs = (%column_defs, %cvar_column_defs);

  my @cvar_column_form_names = ('_include_cvars_from_form', map { "include_cvars_" . $_->name } @{ $self->includeable_cvar_configs });

  my %cvar_column_url_params = (_include_cvars_from_form => 1,
                                map { (
                                  'include_cvars_' . $_->name => $self->include_cvars->{$_->name} ? 1 : 0
                                ) } @{ $self->includeable_cvar_configs });

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'Project',
    output_format         => 'HTML',
    title                 => $::locale->text('Projects'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter), @cvar_column_form_names);
  $report->set_options_from_form;
  $self->models->add_additional_url_params(%cvar_column_url_params);
  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);
  $report->set_options(
    raw_top_info_text     => $self->render('project/report_top',    { output => 0 }),
    raw_bottom_info_text  => $self->render('project/report_bottom', { output => 0 }),
  );
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      _default => {
        by    => 'projectnumber',
        dir   => 1,
      },
      customer       => t8('Customer'),
      description    => t8('Description'),
      projectnumber  => t8('Project Number'),
      project_type   => t8('Project Type'),
      project_status => t8('Project Status'),
      customer_and_description => 1,
    },
    with_objects => [ 'customer', 'project_status', 'project_type' ],
  );
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{"projectnumber:substr::ilike"},  t8('Project Number') ],
    [ $filter->{"description:substr::ilike"},    t8('Description')    ],
    [ $filter->{customer}{"name:substr::ilike"}, t8('Customer')       ],
    [ $filter->{"project_type_id"},              t8('Project Type'),    sub { SL::DB::Manager::ProjectType->find_by(id => $filter->{"project_type_id"})->description }   ],
    [ $filter->{"project_status_id"},            t8('Project Status'),  sub { SL::DB::Manager::ProjectStatus->find_by(id => $filter->{"project_status_id"})->description } ],
  );

  my @flags = (
    [ $filter->{active} eq 'active',    $::locale->text('Active')      ],
    [ $filter->{active} eq 'inactive',  $::locale->text('Inactive')    ],
    [ $filter->{valid}  eq 'valid',     $::locale->text('Valid')       ],
    [ $filter->{valid}  eq 'invalid',   $::locale->text('Invalid')     ],
    [ $filter->{orphaned},              $::locale->text('Orphaned')    ],
  );

  for (@flags) {
    push @filter_strings, "$_->[1]" if $_->[0];
  }
  for (@filters) {
    push @filter_strings, "$_->[1]: " . ($_->[2] ? $_->[2]->() : $_->[0]) if $_->[0];
  }

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub setup_edit_action_bar {
  my ($self, %params) = @_;

  my $is_new = !$self->project->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => 'Project/' . ($is_new ? 'create' : 'update') } ],
          accesskey => 'enter',
        ],
        action => [
          t8('Save as new'),
          submit   => [ '#form', { action => 'Project/create' }],
          disabled => $is_new ? t8('The object has not been saved yet.') : undef,
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'Project/destroy' } ],
        confirm  => $::locale->text('Do you really want to delete this object?'),
        disabled => $is_new                 ? t8('This object has not been saved yet.')
                  : $self->project->is_used ? t8('This object has already been used.')
                  :                           undef,
      ],

      link => [
        t8('Abort'),
        link => $params{callback} || $self->url_for(action => 'list'),
      ],
    );
  }
}

sub setup_list_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#search_form', { action => 'Project/list' } ],
        accesskey => 'enter',
      ],
      link => [
        t8('Add'),
        link => $self->url_for(action => 'new'),
      ],
    );
  }
}

1;
