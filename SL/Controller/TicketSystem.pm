package SL::Controller::TicketSystem;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String qw(t8);
use SL::TicketSystem::Jira;
use SL::Helper::Flash qw(flash);
use Try::Tiny;


__PACKAGE__->run_before('check_auth');

my %providers = (
  jira => 'SL::TicketSystem::Jira',
);

sub check_auth {
  $::auth->assert('config');
}

sub action_ajax_list {
  my ($self) = @_;

  my $defaults      = SL::DB::Default->get();
  my $providerclass = $providers{$defaults->ticket_system_provider} or die 'unknown provider';
  my $provider      = $providerclass->new();
  my $cv_obj        = $::form->{db} eq 'customer' ? SL::DB::Manager::Customer->find_by(id => $::form->{id})
                                                  : SL::DB::Manager::Vendor->find_by(id => $::form->{id});

  $::form->{sort_by}        ||= $provider->default_sort_by;
  $::form->{sort_dir}       //= 0;
  $::form->{include_closed} //= 1;

  my %params  = (search_string => $cv_obj->name); #, message => \$self->{message});
  $params{$_} = $::form->{$_} for qw(include_closed sort_by sort_dir);
  my $objects;
  try {
    $objects = $provider->get_tickets(\%params, \$self->{message});
  } catch {
    $_ =~ m/^no OAuth token / ? flash('info', t8('Create an OAuth token first under Program -> OAuth Tokens'))
                              : flash('error', $_);
    $self->render(\"[% INCLUDE 'common/flash.html' %]", { layout => 0 });
    $::dispatcher->end_request();
  };

  my @prov_cols    = @{$provider->ticket_columns()};
  my @columns      = map { $_->{name} } @prov_cols;
  my @sort_columns = map { $_->{name} } (grep { $_->{sortable} } @prov_cols);

  my %column_defs;
  for my $col (@prov_cols) {
    $column_defs{$col->{name}} = {
      text     => $col->{text},
      sub      => sub { $_[0]->{$col->{name}} },
      obj_link => sub { $_[0]->{$col->{ext_url}} },
      visible  => 1,
    };
  }

  for my $col (@sort_columns) {
    $column_defs{$col}{link} = $self->url_for(
      action         => 'ajax_list',
      callback       => $::form->{callback},
      db             => $::form->{db},
      id             => $cv_obj->id,
      include_closed => $::form->{include_closed},
      sort_by        => $col,
      sort_dir       => ($::form->{sort_by} eq $col ? 1 - $::form->{sort_dir} : $::form->{sort_dir}),
    );
  }

  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_sort_indicator($::form->{sort_by}, $::form->{sort_dir});
  $report->set_options(
    output_format        => 'HTML',
    title                => $provider->title,
    allow_pdf_export     => 0,
    allow_csv_export     => 0,
    raw_top_info_text    => $self->render('ticket_system/report_top',    { output => 0 }),
    raw_bottom_info_text => $self->render('ticket_system/report_bottom', { output => 0 })
  );

  $self->report_generator_list_objects(report => $report, objects => $objects, layout => 0, header => 0);
}


1;
