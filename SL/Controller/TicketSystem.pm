package SL::Controller::TicketSystem;

use strict;

use parent qw(SL::Controller::Base);

use English qw(-no_match_vars);
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String qw(t8);
use SL::TicketSystem::Jira;
use SL::Helper::Flash qw(flash);
use Try::Tiny;


my %providers = (
  jira => 'SL::TicketSystem::Jira',
);

sub action_ajax_list {
  my ($self) = @_;

  my $defaults      = SL::DB::Default->get();
  my $providerclass = $providers{$defaults->ticket_system_provider} or die 'unknown provider';
  my $cv_obj        = $::form->{db} eq 'customer' ? SL::DB::Manager::Customer->find_by(id => $::form->{id})
                                                  : SL::DB::Manager::Vendor->find_by(id => $::form->{id});

  my $provider;
  my $objects;

  eval {
    $provider      = $providerclass->new();

    $::form->{sort_by}        ||= $provider->default_sort_by;
    $::form->{sort_dir}       //= 0;
    $::form->{include_closed} //= 1;

    my %params  = (search_string => $cv_obj->name);
    $params{$_} = $::form->{$_} for qw(include_closed sort_by sort_dir);

    $objects = $provider->get_tickets(\%params, \$self->{message});
    1;
  } or do {
    if (ref($EVAL_ERROR) eq 'SL::X::OAuth::MissingToken') {
      flash('info',  t8('Create an OAuth token first under Program -> OAuth Tokens'));
    } elsif (ref($EVAL_ERROR) eq 'SL::X::OAuth::RefreshFailed') {
      flash('error', t8('OAuth token refresh failed'));
    } else {
      flash('error', $EVAL_ERROR);
    }

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
      sub      => $col->{is_date} ? sub { $_[0]->{$col->{name}}->to_kivitendo }
                                  : sub { $_[0]->{$col->{name}} },
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
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::TicketSystem - Abstraction over different ticket systems
(issue trackers). Used to display ticket data in the customer and vendor
basic data

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
