package SL::Controller::CustomDataExportDesigner;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use List::UtilsBy qw(sort_by);

use SL::DB::CustomDataExportQuery;
use SL::Helper::Flash qw(flash_later);
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(query queries access_rights) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('setup_javascripts');

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->setup_list_action_bar;
  $self->render('custom_data_export_designer/list', title => $::locale->text('Design custom data export queries'));
}

sub action_edit {
  my ($self) = @_;

  my $title = $self->query->id ? t8('Edit custom data export query') : t8('Add custom data export query');

  $self->setup_edit_action_bar;
  $self->render('custom_data_export_designer/edit', title => $title);
}

sub action_edit_parameters {
  my ($self) = @_;

  my $title     = $self->query->id ? t8('Edit custom data export query') : t8('Add custom data export query');
  my @parameters = $self->gather_query_data;

  $self->setup_edit_parameters_action_bar;
  $self->render('custom_data_export_designer/edit_parameters', title => $title, PARAMETERS => \@parameters);
}

sub action_save {
  my ($self) = @_;

  my @parameters = $self->gather_query_data;

  $self->query->parameters(\@parameters);

  $self->query->save;

  flash_later('info', t8('The custom data export has been saved.'));

  $self->redirect_to($self->url_for(action => 'list'));
}

sub action_delete {
  my ($self) = @_;

  $self->query->delete;

  flash_later('info', t8('The custom data export has been deleted.'));

  $self->redirect_to($self->url_for(action => 'list'));
}

#
# filters
#

sub check_auth {
  $::auth->assert('custom_data_export_designer');
}

sub setup_javascripts {
  $::request->layout->add_javascripts('kivi.Validator.js', 'kivi.CustomDataExportDesigner.js');
}

#
# helpers
#

sub init_query   { $::form->{id} ? SL::DB::CustomDataExportQuery->new(id => $::form->{id})->load : SL::DB::CustomDataExportQuery->new }
sub init_queries { scalar SL::DB::Manager::CustomDataExportQuery->get_all_sorted }

sub init_access_rights {
  my @rights = ([ '', t8('Available to all users') ]);
  my $category;

  foreach my $right ($::auth->all_rights_full) {
    # name, description, category

    if ($right->[2]) {
      $category = t8($right->[1]);
    } elsif ($category) {
      push @rights, [ $right->[0], sprintf('%s → %s [%s]', $category, t8($right->[1]), $right->[0]) ];
    }
  }

  return \@rights;
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link      => $self->url_for(action => 'edit'),
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_edit_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Continue'),
        submit    => [ '#form', { action => 'CustomDataExportDesigner/edit_parameters' } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],
      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'CustomDataExportDesigner/delete' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => !$self->query->id ? t8('This object has not been saved yet.')
                  :                      undef,
      ],
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

sub setup_edit_parameters_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'CustomDataExportDesigner/save' } ],
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

sub gather_query_data {
  my ($self) = @_;

  $self->query->$_($::form->{query}->{$_}) for qw(name description sql_query access_right);
  return $self->gather_query_parameters;
}

sub gather_query_parameters {
  my ($self) = @_;

  my %used_parameter_names  = map  { ($_ => 1) }                       $self->query->used_parameter_names;
  my @existing_parameters   = grep { $used_parameter_names{$_->name} } @{ $self->query->parameters // [] };
  my %parameters_by_name    = map  { ($_->name => $_) }                @existing_parameters;
  $parameters_by_name{$_} //= SL::DB::CustomDataExportQueryParameter->new(name => $_, parameter_type => 'text', default_value_type => 'none') for keys %used_parameter_names;

  foreach my $parameter_data (@{ $::form->{parameters} // [] }) {
    my $parameter_obj = $parameters_by_name{ $parameter_data->{name} };
    next unless $parameter_obj;

    $parameter_obj->$_($parameter_data->{$_}) for qw(parameter_type description default_value_type default_value);
  }

  return sort_by { lc $_->name } values %parameters_by_name;
}

1;
