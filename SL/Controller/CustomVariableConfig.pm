package SL::Controller::CustomVariableConfig;

use strict;

use parent qw(SL::Controller::Base);

use List::Util qw(first);

use SL::DB::CustomVariableConfig;
use SL::DB::CustomVariableValidity;
use SL::DB::PartsGroup;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::Presenter::CustomVariableConfig;
use Data::Dumper;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config module module_description flags) ],
  'scalar --get_set_init' => [ qw(translated_types modules) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('check_module');
__PACKAGE__->run_before('load_config', only => [ qw(edit update destroy) ]);

our %translations = (
  text      => t8('Free-form text'),
  textfield => t8('Text field'),
  htmlfield => t8('HTML field'),
  number    => t8('Number'),
  date      => t8('Date'),
  timestamp => t8('Timestamp'),
  bool      => t8('Yes/No (Checkbox)'),
  select    => t8('Selection'),
  customer  => t8('Customer'),
  vendor    => t8('Vendor'),
  part      => t8('Part'),
);

our @types = qw(text textfield htmlfield number date bool select customer vendor part); # timestamp

our @modules = qw(CT Contacts IC Projects RequirementSpecs ShipTo);

#
# actions
#

sub action_list {
  my ($self) = @_;

  my $configs = SL::DB::Manager::CustomVariableConfig->get_all_sorted(where => [ module => $self->module ]);

  $self->setup_list_action_bar;
  $::form->{title} = t8('List of custom variables');
  $::form->header;
  $self->render('custom_variable_config/list',
                title   => t8('List of custom variables'),
                CONFIGS => $configs);
}

sub action_new {
  my ($self) = @_;

  $self->config(SL::DB::CustomVariableConfig->new(module => $self->module));
  $self->show_form(title => t8('Add custom variable'));
}

sub show_form {
  my ($self, %params) = @_;

  $self->flags({
    map { split m/=/, $_, 2 }
    split m/:/, ($self->config->flags || '')
  });

  $params{all_partsgroups} = SL::DB::Manager::PartsGroup->get_all();

  $::request->layout->use_javascript("${_}.js") for qw(jquery.selectboxes jquery.multiselect2side);
  $self->setup_form_action_bar;
  $self->render('custom_variable_config/form', %params);
}

sub action_edit {
  my ($self) = @_;

  $self->show_form(title => t8('Edit custom variable'));
}

sub action_create {
  my ($self) = @_;

  $self->config(SL::DB::CustomVariableConfig->new);
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  # delete relationship to partsgroups (for filter) before cvar can be deleted
  $self->config->update_attributes(partsgroups => []);

  if (eval { $self->config->delete; 1; }) {
    flash_later('info',  t8('The custom variable has been deleted.'));
  } else {
    flash_later('error', t8('The custom variable is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list', module => $self->module);
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::CustomVariableConfig->reorder_list(@{ $::form->{cvarcfg_id} || [] });

  $self->render(\'', { type => 'json' }); # ' make emacs happy
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub check_module {
  my ($self)          = @_;

  $::form->{module} ||= 'CT';
  my $mod_desc        = first { $_->{module} eq $::form->{module} } @{ $self->modules };
  die "Invalid 'module' parameter '" . $::form->{module} . "'" if !$mod_desc;

  $self->module($mod_desc->{module});
  $self->module_description($mod_desc->{description});
}

sub load_config {
  my ($self) = @_;

  $self->config(SL::DB::CustomVariableConfig->new(id => $::form->{id})->load);
}

#
# helpers
#

sub get_translation {
  my ($self, $type) = @_;

  return $translations{$type};
}

sub init_translated_types {
  my ($self) = @_;

  return [ map { { type => $_, translation => $translations{$_} } } @types ];
}

sub init_modules {
  my ($self, %params) = @_;

  return [
    sort { $a->{description}->translated cmp $b->{description}->translated } (
    map +{ module => $_, description => $SL::Presenter::CustomVariableConfig::t8{$_} },
    @modules
  )];
}

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->config->id;

  my $params = delete($::form->{config}) || { };
  delete $params->{id};

  if ($self->module eq 'IC') {
    $params->{partsgroups} = [] if !$params->{flag_partsgroup_filter};
  } else {
    delete $params->{flag_partsgroup_filter};
    $params->{partsgroups} = [];
  }

  $params->{partsgroups}       ||= []; # The list is empty, if control is not send by the browser.
  $params->{default_value}       = $::form->parse_amount(\%::myconfig, $params->{default_value}) if $params->{type} eq 'number';
  $params->{included_by_default} = 0                                                             if !$params->{includeable};
  $params->{flags}               = join ':', map { m/^flag_(.*)/; "${1}=" . delete($params->{$_}) } grep { m/^flag_/ } keys %{ $params };

  $self->config->assign_attributes(%{ $params }, module => $self->module);

  my @errors = $self->config->validate;

  if (@errors) {
    flash('error', $_) for @errors;
    $self->show_form(title => $is_new ? t8('Add new custom variable') : t8('Edit custom variable'));
    return;
  }

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    $self->config->save;
    $self->_set_cvar_validity() if $is_new;
    1;
  }) or do { die SL::DB->client->error };

  flash_later('info', $is_new ? t8('The custom variable has been created.') : t8('The custom variable has been saved.'));
  $self->redirect_to(action => 'list', module => $self->module);
}

sub _set_cvar_validity {
  my ($self) = @_;

  my $flags = {
    map { split m/=/, $_, 2 }
    split m/:/, ($self->config->flags || '')
  };

  # nothing to do to set valid
  return if !$flags->{defaults_to_invalid};

  my $all_parts  = SL::DB::Manager::Part->get_all(where => [ or => [ obsolete => 0, obsolete => undef ] ]);
  foreach my $part (@{ $all_parts }) {
    SL::DB::CustomVariableValidity->new(config_id => $self->config->id, trans_id => $part->id)->save;
  }
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Add'),
        link => $self->url_for(action => 'new', module => $self->module),
      ],
    );
  }
}

sub setup_form_action_bar {
  my ($self) = @_;

  my $is_new = !$self->config->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => 'CustomVariableConfig/' . ($is_new ? 'create' : 'update') } ],
          checks    => [ 'check_prerequisites' ],
          accesskey => 'enter',
        ],

        action => [
          t8('Save as new'),
          submit => [ '#form', { action => 'CustomVariableConfig/create'} ],
          checks => [ 'check_prerequisites' ],
          not_if => $is_new,
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'CustomVariableConfig/destroy' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => $is_new ? t8('This object has not been saved yet.') : undef,
      ],

      'separator',

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list', module => $self->module),
      ],
    );
  }
}

1;
