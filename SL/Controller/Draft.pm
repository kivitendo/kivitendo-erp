package SL::Controller::Draft;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash);
use SL::Locale::String qw(t8);
use SL::Request;
use SL::DB::Draft;
use SL::DBUtils qw(selectall_hashref_query);
use SL::YAML;
use List::Util qw(max);

use Rose::Object::MakeMethods::Generic (
 scalar => [ qw() ],
 'scalar --get_set_init' => [ qw(module submodule draft) ],
);

__PACKAGE__->run_before('check_auth');

my %allowed_modules = map { $_ => "bin/mozilla/$_.pl" } qw(is ir ar ap gl);

#
# actions
#

sub action_draft_dialog {
  my ($self) = @_;
  $self->js
    ->dialog->open({
      html   => $self->dialog_html,
      id     => 'save_draft',
      dialog => {
        title => t8('Drafts'),
      },
    })
    ->render;
}

sub action_save {
  my ($self) = @_;

  my $id          = $::form->{id};
  my $description = $::form->{description} or die 'need description';
  my $form        = $self->_build_form;

  my $draft = SL::DB::Manager::Draft->find_by_or_create(id => $id);

  $draft->id($self->module . '-' . $self->submodule . '-' . Common::unique_id()) unless $draft->id;

  $draft->assign_attributes(
    module      => $self->module,
    submodule   => $self->submodule,
    description => $description,
    form        => SL::YAML::Dump($form),
    employee_id => SL::DB::Manager::Employee->current->id,
  );

  $self->draft($draft);

  if (!$draft->save) {
    flash('error', t8('There was an error saving the draft'));
    $self->js
      ->html('#save_draft', $self->dialog_html)
      ->render;
  } else {
    $self->js
      ->flash('info', t8("Draft saved."))
      ->dialog->close('#save_draft')
      ->val('#draft_id', $draft->id)
      ->render;
  }
}

sub action_load {
  my ($self) = @_;

  if (!$allowed_modules{ $self->draft->module }) {
    $::form->error(t8('Unknown module: #1', $self->draft->module));
  } else {
    package main;
    require $allowed_modules{ $self->draft->module };
  }
  my $params = delete $::form->{form};
  my $new_form = SL::YAML::Load($self->draft->form);
  $::form->{$_} = $new_form->{$_} for keys %$new_form;
  $::form->{"draft_$_"} = $self->draft->$_ for qw(id description);

  if ($params && 'HASH' eq ref $params) {
    $::form->{$_} = $params->{$_} for keys %$params;
  }
  $::form->{script} = $self->draft->module . '.pl';
  ::show_draft();
}

sub action_delete {
  my ($self) = @_;

  $self->module($self->draft->module);
  $self->submodule($self->draft->submodule);

  if (!$self->draft->delete) {
    flash('error', t8('There was an error deleting the draft'));
    $self->js
      ->html('#save_draft', $self->dialog_html)
      ->render;
  } else {
    flash('info', t8('Draft deleted'));

    $self->js
      ->html('#save_draft', $self->dialog_html)
      ->render;
  }
}

#
# helpers
#

sub _build_form {
  my $last_index = max map { /form\[(\d+)\]/ ? $1 : 0 } keys %$::form;
  my $new_form = {};

  for my $i (0..$last_index) {
    SL::Request::_store_value($new_form, $::form->{"form[$i][name]"}, $::form->{"form[$i][value]"});
  }

  return $new_form;
}

sub draft_list {
  my ($self) = @_;

  if ($::auth->assert('all_drafts_edit', 1)) {
   my $result = selectall_hashref_query($::form, $::form->get_standard_dbh, <<SQL, $self->module, $self->submodule);
    SELECT d.*, date(d.itime) AS date
    FROM drafts d
    WHERE (d.module      = ?)
      AND (d.submodule   = ?)
    ORDER BY d.itime
SQL
  } else {
    my $result = selectall_hashref_query($::form, $::form->get_standard_dbh, <<SQL, $self->module, $self->submodule, SL::DB::Manager::Employee->current->id);
    SELECT d.*, date(d.itime) AS date
    FROM drafts d
    WHERE (d.module      = ?)
      AND (d.submodule   = ?)
      AND (d.employee_id = ?)
    ORDER BY d.itime
SQL
  }
}

sub dialog_html {
  my ($self) = @_;

  $self->render('drafts/form', { layout => 0, output => 0 },
    drafts_list => $self->draft_list
  )
}

sub init_module {
  $::form->{module}      or die 'need module';
}

sub init_submodule {
  $::form->{submodule}   or die 'need submodule';
}

sub init_draft {
  SL::DB::Manager::Draft->find_by(id => $::form->{id}) or die t8('Could not load this draft');
}

sub check_auth {
  $::auth->assert('vendor_invoice_edit | invoice_edit | ap_transactions | ar_transactions');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Draft

=head1 DESCRIPTION

Encapsulates the old draft mechanism. Use and improvement are discuraged as
long as the storage is not upgrade safe.

=head1 TODO

  - optional popup on entry

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
