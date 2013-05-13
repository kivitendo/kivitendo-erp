package SL::Controller::RequirementSpec;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use SL::ClientJS;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;
use SL::Controller::Helper::RequirementSpec;
use SL::DB::Customer;
use SL::DB::Project;
use SL::DB::RequirementSpecComplexity;
use SL::DB::RequirementSpecRisk;
use SL::DB::RequirementSpecStatus;
use SL::DB::RequirementSpecType;
use SL::DB::RequirementSpec;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::Template::LaTeX;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(requirement_spec_item customers types statuses db_args flat_filter visible_item visible_section) ],
  'scalar --get_set_init' => [ qw(requirement_spec complexities risks projects copy_source js) ],
);

__PACKAGE__->run_before('setup');
__PACKAGE__->run_before('load_select_options',  only => [ qw(new ajax_edit create update list) ]);


__PACKAGE__->get_models_url_params('flat_filter');
__PACKAGE__->make_paginated(
  MODEL         => 'RequirementSpec',
  PAGINATE_ARGS => 'db_args',
  ONLY          => [ qw(list) ],
);

__PACKAGE__->make_sorted(
  MODEL         => 'RequirementSpec',
  ONLY          => [ qw(list) ],

  DEFAULT_BY    => 'customer',
  DEFAULT_DIR   => 1,

  customer      => t8('Customer'),
  title         => t8('Title'),
  type          => t8('Requirement Spec Type'),
  status        => t8('Requirement Spec Status'),
  projectnumber => t8('Project Number'),
  version       => t8('Version'),
  mtime         => t8('Last modification'),
);

#
# actions
#


sub action_list {
  my ($self) = @_;

  $self->setup_db_args_from_filter;
  $self->flat_filter({ map { $_->{key} => $_->{value} } $::form->flatten_variables('filter') });

  $self->prepare_report;

  my $requirement_specs = $self->get_models(%{ $self->db_args });

  $self->report_generator_list_objects(report => $self->{report}, objects => $requirement_specs);
}

sub action_new {
  my ($self) = @_;

  $self->requirement_spec(SL::DB::RequirementSpec->new(is_template => $::form->{is_template}));

  if ($self->copy_source) {
    $self->requirement_spec->$_($self->copy_source->$_) for qw(type_id status_id customer_id title hourly_rate)
  }

  $self->render('requirement_spec/new', title => $self->requirement_spec->is_template ? t8('Create a new requirement spec template') : t8('Create a new requirement spec'));
}

sub action_ajax_edit {
  my ($self) = @_;

  $self->render('requirement_spec/_form', { layout => 0 }, submit_as => 'ajax');
}

sub action_ajax_show_time_and_cost_estimate {
  my ($self) = @_;

  $self->render('requirement_spec/_show_time_and_cost_estimate', { layout => 0 });
}

sub action_ajax_cancel_time_and_cost_estimate {
  my ($self) = @_;

  my $html   = $self->render('requirement_spec/_show_time_and_cost_estimate', { output => 0 });

  $self->js
   ->replaceWith('#time_cost_estimate', $html)
   ->render($self);
}

sub action_ajax_edit_time_and_cost_estimate {
  my ($self) = @_;

  my $html   = $self->render('requirement_spec/_edit_time_and_cost_estimate', { output => 0 });

  $self->js
   ->replaceWith('#time_cost_estimate', $html)
   ->render($self);
}

sub action_ajax_save_time_and_cost_estimate {
  my ($self) = @_;

  $self->requirement_spec->db->do_transaction(sub {
    # Make Emacs happy
    1;
    foreach my $attributes (@{ $::form->{requirement_spec_items} || [] }) {
      SL::DB::RequirementSpecItem
        ->new(id => delete $attributes->{id})
        ->load
        ->update_attributes(%{ $attributes });
    }

    1;
  });

  my $html = $self->render('requirement_spec/_show_time_and_cost_estimate', { output => 0 });
  $self->js->replaceWith('#time_cost_estimate', $html);

  if ($self->visible_section) {
    $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $self->visible_section);
    $self->js->html('#column-content', $html);
  }

  $self->js->render($self);
}

sub action_show {
  my ($self) = @_;

  my $title  = $self->requirement_spec->is_template ? t8('Show requirement spec template') : t8('Show requirement spec');
  my $item   = $::form->{requirement_spec_item_id} ? SL::DB::RequirementSpecItem->new(id => $::form->{requirement_spec_item_id})->load : @{ $self->requirement_spec->sections }[0];
  $self->requirement_spec_item($item);

  $self->render('requirement_spec/show', title => $title);
}

sub action_create {
  my ($self) = @_;

  $self->requirement_spec(SL::DB::RequirementSpec->new);
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->requirement_spec->delete; 1; }) {
    flash_later('info',  t8('The requirement spec has been deleted.'));
  } else {
    flash_later('error', t8('The requirement spec is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}

sub action_revert_to {
  my ($self, %params) = @_;

  return $self->js->error(t8('Cannot revert a versioned copy.'))->render($self) if $self->requirement_spec->working_copy_id;

  my $versioned_copy = SL::DB::RequirementSpec->new(id => $::form->{versioned_copy_id})->load;

  $self->requirement_spec->copy_from(
    $versioned_copy,
    version_id => $versioned_copy->version_id,
  );

  flash_later('info', t8('The requirement spec has been reverted to version #1.', $self->requirement_spec->version->version_number));
  $self->js->redirect_to($self->url_for(action => 'show', id => $self->requirement_spec->id))->render($self);
}

sub action_create_pdf {
  my ($self, %params) = @_;

  my %result = SL::Template::LaTeX->parse_and_create_pdf('requirement_spec.tex', SELF => $self, rspec => $self->requirement_spec);

  $::form->error(t8('Conversion to PDF failed: #1', $result{error})) if $result{error};

  my $attachment_name  =  $self->requirement_spec->type->description . ' ' . ($self->requirement_spec->working_copy_id || $self->requirement_spec->id);
  $attachment_name    .=  ' (v' . $self->requirement_spec->version->version_number . ')' if $self->requirement_spec->version;
  $attachment_name    .=  '.pdf';
  $attachment_name     =~ s/[^\wäöüÄÖÜß \-\+\(\)\[\]\{\}\.,]+/_/g;

  $self->send_file($result{file_name}, type => 'application/pdf', name => $attachment_name);
  unlink $result{file_name};
}

sub action_select_template_to_paste {
  my ($self) = @_;

  my @templates = grep { @{ $_->sections } || @{ $_->text_blocks } } @{ SL::DB::Manager::RequirementSpec->get_all(where => [ is_template => 1 ], sort_by => 'lower(title)') };
  $self->render('requirement_spec/select_template_to_paste', { layout => 0 }, TEMPLATES => \@templates);
}

#
# filters
#

sub setup {
  my ($self) = @_;

  $::auth->assert('sales_quotation_edit');
  $::request->{layout}->use_stylesheet("${_}.css") for qw(jquery.contextMenu requirement_spec);
  $::request->{layout}->use_javascript("${_}.js") for qw(jquery.jstree jquery/jquery.contextMenu client_js requirement_spec);
  $self->init_visible_section;

  return 1;
}

sub init_complexities {
  my ($self) = @_;
  return SL::DB::Manager::RequirementSpecComplexity->get_all_sorted;
}

sub init_risks {
  my ($self) = @_;
  return SL::DB::Manager::RequirementSpecRisk->get_all_sorted;
}

sub init_projects {
  my ($self) = @_;
  $self->projects(SL::DB::Manager::Project->get_all_sorted);
}

sub init_requirement_spec {
  my ($self) = @_;
  $self->requirement_spec(SL::DB::RequirementSpec->new(id => $::form->{id})->load || die "No such requirement spec") if $::form->{id};
}

sub init_copy_source {
  my ($self) = @_;
  $self->copy_source(SL::DB::RequirementSpec->new(id => $::form->{copy_source_id})->load) if $::form->{copy_source_id};
}

sub init_js {
  my ($self) = @_;
  $self->js(SL::ClientJS->new);
}

sub load_select_options {
  my ($self) = @_;

  my @filter = ('!obsolete' => 1);
  @filter    = ( or => [ @filter, id => $self->requirement_spec->customer_id ] ) if $self->requirement_spec && $self->requirement_spec->customer_id;

  $self->customers(SL::DB::Manager::Customer->get_all_sorted(where => \@filter));
  $self->statuses( SL::DB::Manager::RequirementSpecStatus->get_all_sorted);
  $self->types(    SL::DB::Manager::RequirementSpecType->get_all_sorted);
}

#
# helpers
#

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->requirement_spec->id;
  my $params = delete($::form->{requirement_spec}) || { };

  $self->requirement_spec->assign_attributes(%{ $params });

  my $title  = $is_new && $self->requirement_spec->is_template ? t8('Create a new requirement spec template')
             : $is_new                                         ? t8('Create a new requirement spec')
             :            $self->requirement_spec->is_template ? t8('Edit requirement spec template')
             :                                                   t8('Edit requirement spec');

  my @errors = $self->requirement_spec->validate;

  if (@errors) {
    return $self->js->error(@errors)->render($self) if $::request->is_ajax;

    flash('error', @errors);
    $self->render('requirement_spec/new', title => $title);
    return;
  }

  my $db = $self->requirement_spec->db;
  if (!$db->do_transaction(sub {
    if ($self->copy_source) {
      $self->requirement_spec($self->copy_source->create_copy(%{ $params }));
    } else {
      $self->requirement_spec->save;
    }
  })) {
    $::lxdebug->message(LXDebug::WARN(), "Error: " . $db->error);
    @errors = ($::locale->text('Saving failed. Error message from the database: #1'), $db->error);
    return $self->js->error(@errors)->render($self) if $::request->is_ajax;

    $self->requirement_spec->id(undef) if $is_new;
    flash('error', @errors);
    return $self->render('requirement_spec/new', title => $title);
  }

  my $info = $self->requirement_spec->is_template ? t8('The requirement spec template has been saved.') : t8('The requirement spec has been saved.');

  if ($::request->is_ajax) {
    my $html = $self->render('requirement_spec/_header', { output => 0 });
    return $self->invalidate_version
      ->replaceWith('#requirement-spec-header', $html)
      ->flash('info', $info)
      ->render($self);
  }

  flash_later('info', $info);
  $self->redirect_to(action => 'show', id => $self->requirement_spec->id);
}

sub setup_db_args_from_filter {
  my ($self) = @_;

  $self->{filter} = {};
  my %args = parse_filter(
    $::form->{filter},
    with_objects => [ 'customer', 'type', 'status', 'project' ],
    launder_to   => $self->{filter},
  );

  $args{where} = [
    and => [
      @{ $args{where} || [] },
      working_copy_id => undef,
      is_template     => $::form->{is_template} ? 1 : 0,
    ]];

  $self->db_args(\%args);
}

sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->get_callback;

  my $is_template = $::form->{is_template};
  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = $is_template ? qw(title mtime) : qw(title customer status type projectnumber mtime version);
  my @sortable    = $is_template ? qw(title mtime) : qw(title customer status type projectnumber mtime);

  my %column_defs = (
    title         => { obj_link => sub { $self->url_for(action => 'show', id => $_[0]->id, callback => $callback) } },
    mtime         => { sub      => sub { ($_[0]->mtime || $_[0]->itime)->to_kivitendo(precision => 'minute') } },
  );

  if (!$is_template) {
    %column_defs = (
      %column_defs,
      customer      => { raw_data => sub { $self->presenter->customer($_[0]->customer, display => 'table-cell', callback => $callback) },
                         sub      => sub { $_[0]->customer->name } },
      projectnumber => { raw_data => sub { $self->presenter->project($_[0]->project, display => 'table-cell', callback => $callback) },
                         sub      => sub { $_[0]->project_id ? $_[0]->project->projectnumber : '' } },
      status        => { sub      => sub { $_[0]->status->description } },
      type          => { sub      => sub { $_[0]->type->description } },
      version       => { sub      => sub { $_[0]->version_id ? $_[0]->version->version_number : t8('Working copy without version') } },
    );
  }

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'RequirementSpec',
    output_format         => 'HTML',
    raw_top_info_text     => $self->render('requirement_spec/report_top',    { output => 0 }, is_template => $is_template),
    raw_bottom_info_text  => $self->render('requirement_spec/report_bottom', { output => 0 }),
    title                 => $is_template ? t8('Requirement Spec Templates') : t8('Requirement Specs'),
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

sub invalidate_version {
  my ($self) = @_;

  my $rspec  = SL::DB::RequirementSpec->new(id => $self->requirement_spec->id)->load;
  return $self->js if $rspec->is_template;

  $rspec->invalidate_version;

  my $html = $self->render('requirement_spec/_version', { output => 0 }, requirement_spec => $rspec);
  return $self->js->html('#requirement_spec_version', $html);
}

1;
