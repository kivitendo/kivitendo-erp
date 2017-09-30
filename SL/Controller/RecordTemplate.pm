package SL::Controller::RecordTemplate;

use strict;

use base qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash);
use SL::Locale::String qw(t8);
use SL::DB::RecordTemplate;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(template_type template templates data) ],
);

__PACKAGE__->run_before('check_auth');

my %modules = (
  ar_transaction => {
    controller    => 'ar.pl',
    load_action   => 'load_record_template',
    save_action   => 'save_record_template',
    form_selector => '#form',
  },

  ap_transaction => {
    controller    => 'ap.pl',
    load_action   => 'load_record_template',
    save_action   => 'save_record_template',
    form_selector => '#form',
  },

  gl_transaction => {
    controller    => 'gl.pl',
    load_action   => 'load_record_template',
    save_action   => 'save_record_template',
    form_selector => '#form',
  },
);

#
# actions
#

sub action_show_dialog {
  my ($self) = @_;
  $self
    ->js
    ->dialog->open({
      html   => $self->dialog_html,
      id     => 'record_template_dialog',
      dialog => {
        title => t8('Record templates'),
      },
    })
    ->focus("#template_filter")
    ->render;
}

sub action_rename {
  my ($self) = @_;

  $self->template_type($self->template->template_type);
  $self->template->update_attributes(template_name => $::form->{template_name});

  $self
    ->js
    ->html('#record_template_dialog', $self->dialog_html)
    ->focus("#record_template_dialog_new_template_name")
    ->reinit_widgets
    ->render;
}

sub action_delete {
  my ($self) = @_;

  $self->template_type($self->template->template_type);
  $self->template->delete;

  $self
    ->js
    ->html('#record_template_dialog', $self->dialog_html)
    ->focus("#record_template_dialog_new_template_name")
    ->reinit_widgets
    ->render;
}

sub action_filter_templates {
  my ($self) = @_;

  $self->{template_filter} = $::form->{template_filter};

  $self
    ->js
    ->html('#record_template_dialog', $self->dialog_html)
    ->focus("#record_template_dialog_new_template_name")
    ->reinit_widgets
    ->focus("#template_filter")
    ->render();
}

#
# helpers
#

sub check_auth {
  $::auth->assert('ap_transactions | ar_transactions | gl_transactions');
}

sub init_template_type { $::form->{template_type} or die 'need template_type'   }
sub init_data          { $modules{ $_[0]->template_type }                       }
sub init_template      { SL::DB::RecordTemplate->new(id => $::form->{id})->load }

sub init_templates {
  my ($self) = @_;
  return scalar SL::DB::Manager::RecordTemplate->get_all_sorted(
    where => [ template_type => $self->template_type,
              (template_name => { ilike => '%' . $::form->{template_filter} . '%' })x!! ($::form->{template_filter})
             ],
  );
}

sub dialog_html {
  my ($self) = @_;

  return $self->render('record_template/dialog', { layout => 0, output => 0 });
}

1;
