package SL::Controller::Countries;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Country;
use SL::Helper::Flash;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String qw(t8);
use SL::Presenter::Tag qw(input_tag html_tag);

__PACKAGE__->run_before('check_auth');


sub action_list {
  my ($self, %params) = @_;

  $self->setup_action_bar();
  $::form->{title} = $::locale->text('Country Names');

  my @columns = qw(iso2 description);
  my %column_defs = (
    iso2        => { text => 'ISO 3166-1' },
    description => { text => $::locale->text('Name') },
  );
  map { $column_defs{$_}{visible} = 1 } @columns;

  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(
    title                => $::form->{title},
    allow_chart_export   => 0,
    allow_csv_export     => 0,
    allow_pdf_export     => 0,
    raw_top_info_text    => '<div class="wrapper"><form id="form">' .
      html_tag('p', $::locale->text('The ISO 3166-1 alpha-2 codes are required for Factur-X/ZUGFeRD invoices. The corresponding names are printed on records.')),
    raw_bottom_info_text => '</form></div>',
  );

  foreach my $c (@{SL::DB::Manager::Country->get_all(sort_by => 'description')}) {
    $report->add_data({
      iso2        => { data => $c->iso2 },
      description => { raw_data => input_tag('description.' . $c->id, $c->description, class => 'wi-wide') },
    });
  }

  $self->render(\$report->generate_html_content());
}

sub action_save {
  my ($self, %params) = @_;

  my %country_desc = %{$::form->{description}};
  foreach my $id (keys %country_desc) {
    my $obj = SL::DB::Country->new(id => $id)->load;
    $obj->description($country_desc{$id});
    $obj->save;
  }
  flash_later('info', $::locale->text('saved'));

  $self->redirect_to(action => 'list');
}

sub check_auth {
  $::auth->assert('admin');
}

sub setup_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'Countries/save' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
