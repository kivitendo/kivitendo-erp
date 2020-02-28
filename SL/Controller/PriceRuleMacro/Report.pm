package SL::Controller::PriceRuleMacro::Report;

use strict;
use parent qw(Rose::Object);

use Scalar::Util qw(weaken);
use SL::Locale::String qw(t8);
use SL::ReportGenerator;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;
use SL::DB::PriceRuleMacro;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(filter_summary) ],
  'scalar --get_set_init' => [ qw(
    models report
  ) ],
);

# sub controller back delegation
use SL::Helper::Object (
  delegate => [
    controller => [ qw(render _run_action) ],
  ],
);

sub action_list {
  my ($self) = @_;

  $self->make_filter_summary;

  $self->prepare_report;

  $self->controller->report_generator_list_objects(
    report  => $self->report,
    objects => $self->models->get,
    layout  => !$::form->{inline},
    header  => !$::form->{inline},
    options => {
      action_bar_setup_hook => sub { $self->setup_search_action_bar(report_generator_actions => [ @_ ]) },
    },
  );
}

sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->models->get_callback;
  my $report      = $self->report;

  my @columns     = qw(name type priority name items);
  my @sortable    = qw(name type priority name notes      );

  my %column_defs = (
    name          => { obj_link => sub { $self->controller->url_for(action => 'load', 'price_rule_macro.id' => $_[0]->id, callback => $callback) } },
    priority      => { sub  => sub { $_[0]->priority_as_text } },
    obsolete      => { sub  => sub { $_[0]->obsolete_as_bool_yn } },
    notes         => { sub  => sub { $_[0]->notes } },
#     items         => { sub  => sub { $_[0]->item_summary } },
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->models->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'PriceRuleMacro',
    output_format         => 'HTML',
    title                 => t8('Price Rules'),
    allow_pdf_export      => !$::form->{inline},
    allow_csv_export      => !$::form->{inline},
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->get_models_url_params(sub{ map { $_ => $::form->{$_} } qw(inline) });
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);
  $report->set_options(
    raw_bottom_info_text  => $self->controller->render('price_rule_macro/report_bottom', { output => 0 }),
    raw_top_info_text     => $self->controller->render('price_rule_macro/report_top', { output => 0 }),
  );
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{"name:substr::ilike"}, t8('Name')  ],
    [ $filter->{"price:number"},       t8('Price') ],
    [ $filter->{"discount:number"},    t8('Discount') ],
  );

  for (@filters) {
    push @filter_strings, "$_->[1]: $_->[0]" if $_->[0];
  }

  $self->filter_summary(join ', ', @filter_strings);
}

sub setup_search_action_bar {
  my ($self, %params) = @_;
  require SL::Controller::PriceRule;

  return if $::form->{inline};

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#search_form', { action => 'PriceRuleMacro/list' } ],
        accesskey => 'enter',
        checks    => [ [ 'kivi.validate_form', '#search_form' ] ],
      ],

      'separator',

      @{ $params{report_generator_actions} },

      combobox => [
        action => [
          t8('Add'),
        ],
        link => [
          t8('New Sales Price Rule'),
          link => $self->controller->url_for(action => 'new', 'price_rule_macro.type' => 'customer', callback => $self->models->get_callback),
        ],
        link => [
          t8('New Purchase Price Rule'),
          link => $self->controller->url_for(action => 'new', 'price_rule_macro.type' => 'vendor', callback => $self->models->get_callback),
        ],
      ], # end of combobox "Add"
      link => [
        t8('Advanced Search'),
        link => SL::Controller::PriceRule->url_for(action => 'list'),
        tooltip => t8('Switch to advanced search'),
      ],
    );
  }
}

sub init_report {
  SL::ReportGenerator->new(\%::myconfig, $::form);
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self->controller,
    sorted => {
      name     => t8('Name'),
      type     => t8('Type'),
      priority => t8('Priority'),
      obsolete => t8('Obsolete'),
      digest    => t8('Rule Details'),
    },
  );
}

sub controller {
  if (@_ > 1) {
    weaken($_[0]{controller} = $_[1]);
  }

  $_[0]{controller};
}

1;
