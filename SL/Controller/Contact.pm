package SL::Controller::Contact;

use strict;
use parent qw(SL::Controller::Base);


use SL::Locale::String qw(t8);
use SL::Util qw(trim);
use List::Util qw(first);
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::Controller::Helper::ParseFilter;
use SL::DB::Contact;
use SL::DB::ContactDepartment;
use SL::DB::ContactTitle;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(user_has_edit_rights) ],
  'scalar --get_set_init' => [ qw(contact) ],
);

__PACKAGE__->run_before(
  '_instantiate_args',
  only => [
    'save',
    'delete',
  ]
);

__PACKAGE__->run_before('_check_auth');

sub action_ajaj_autocomplete {
  my ($self, %params) = @_;

  my ($model, $matches);

  $model   = SL::Controller::Helper::GetModels->new(
    controller   => $self,
    model        => 'Contact',
    sorted => {
      _default  => {
        by => 'cp_name',
        dir  => 1,
      },
      cp_name   => t8('Name'),
    },
  );

  # if someone types something, and hits enter, assume he entered the full name.
  # if something matches, treat that as the sole match
  # unfortunately get_models can't do more than one per package atm, so we do it
  # the oldfashioned way.
  if ($::form->{prefer_exact}) {
    my $exact_matches;
    if (1 == scalar @{ $exact_matches = SL::DB::Manager::Contact->get_all(
      query => [
        or => [
          cp_name      => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
          cp_givenname => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
          cp_number    => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
          cp_email     => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
        ]
      ],
      limit => 2,
    ) }) {
      $matches = $exact_matches;
    }
  }

  $matches //= $model->get;

  my @hashes = map {
   +{
     label => (join ' ', grep $_, $_->full_name_dep, $_->cp_email),
     id    => $_->cp_id,
    }
  } @{ $matches };

  $self->render(\ SL::JSON::to_json(\@hashes), { layout => 0, type => 'json', process => 0 });
}



sub action_edit {
  my ($self) = @_;

  $self->_pre_render();
  $self->render(
    'contact/form',
    title => $self->contact->cp_id ? t8('Edit Contact') . ' - ' . $self->contact->full_name : t8('New contact'),
    %{$self->{template_args}}
  );
}

sub action_save {
  my ($self) = @_;

  $self->contact->cp_title(trim($self->contact->cp_title));
  my $save_contact_title      = $self->contact->cp_title
    && $::instance_conf->get_contact_titles_use_textfield
    && SL::DB::Manager::ContactTitle->get_all_count(where => [description => $self->contact->cp_title]) == 0;

  $self->contact->cp_abteilung(trim($self->contact->cp_abteilung));
  my $save_contact_department = $self->contact->cp_abteilung
    && $::instance_conf->get_contact_departments_use_textfield
    && SL::DB::Manager::ContactDepartment->get_all_count(where => [description => $self->contact->cp_abteilung]) == 0;


  if( $self->contact->cp_name ne '' || $self->contact->cp_givenname ne '' ) {
    SL::DB::ContactTitle     ->new(description => $self->contact->cp_title)    ->save if $save_contact_title;
    SL::DB::ContactDepartment->new(description => $self->contact->cp_abteilung)->save if $save_contact_department;

    $self->contact->save(cascade => 1);
  }

  my @redirect_params = (
    action => 'edit',
    id     => $self->contact->cp_id,
  );

  if ($::form->{link_with_cv_id}) {
    if ($self->contact->cp_id) {
      my $class = $::form->{link_with_cv_db} eq 'customer' ? 'Customer' : 'Vendor';
      my $cv_obj = "SL::DB::$class"->new(id => $::form->{link_with_cv_id})->load;
      $cv_obj->link_contact($self->contact);
    } else {
      push @redirect_params, (
        link_with_cv_id => $::form->{link_with_cv_id},
        link_with_cv_db => $::form->{link_with_cv_db},
      );
    }
  }

  $self->redirect_to(@redirect_params);
}

sub action_delete {
  my ($self) = @_;
  $self->contact->delete;
  $self->redirect_to($::form->{callback});
}

sub action_add_cv {
  my ($self) = @_;

  my $class = $::form->{cv_db} eq 'customer' ? 'Customer' : 'Vendor';

  my $cv_obj = "SL::DB::$class"->new(id => $::form->{cv_id})->load;

  my $was_already_linked = first { $_->cp_id == $self->contact->cp_id } @{ $cv_obj->contacts };
  $cv_obj->link_contact($self->contact);

  unless ($was_already_linked) {
    my $row_as_html = $self->p->render('contact/_cv_row', cv => $cv_obj);
    $self->js->before("#add_$::form->{cv_db}_row", $row_as_html);
  }

  $self->js->val(".add_$::form->{cv_db}_input", '');
  $self->js->render();
}

sub action_add_contact {
  my ($self) = @_;

  my $class = $::form->{cv_db} eq 'customer' ? 'Customer' : 'Vendor';

  my $cv_obj = "SL::DB::$class"->new(id => $::form->{cv_id})->load;

  my $was_already_linked = first { $_->cp_id == $self->contact->cp_id } @{ $cv_obj->contacts };

  $cv_obj->link_contact($self->contact);

  unless ($was_already_linked) {
    my $row_as_html = $self->p->render('contact/_contact_row', contact => $self->contact,
      callback => $self->url_for(controller => 'CustomerVendor', action => 'edit', id => $cv_obj->id, db => $::form->{cv_db})
    );
    $self->js->before("#add_contact_row", $row_as_html);
  }

  $self->js->val(".add_contact_input", '');
  $self->js->render();
}

sub action_set_main_contact {
  my ($self) = @_;

  my $class = $::form->{cv_db} eq 'customer' ? 'Customer' : 'Vendor';

  my $cv_obj = "SL::DB::$class"->new(id => $::form->{cv_id})->load;

  my $cv_contact = "SL::DB::Manager::${class}Contact"->get_first(query => [
    "$::form->{cv_db}_id" => $::form->{cv_id},
    main => 1,
  ]);
  if ($cv_contact) {
    $cv_contact->main(0);
    $cv_contact->save;
    $self->js->val("#main_$cv_contact->{contact_id}", '0');
  }

  $cv_obj->link_contact($self->contact, main => 1);

  $self->js->render();
}

sub action_detach_cv {
  my ($self) = @_;

  my $class = $::form->{cv_db} eq 'customer' ? 'Customer' : 'Vendor';

  my $cv_obj = "SL::DB::$class"->new(id => $::form->{cv_id})->load;
  $cv_obj->detach_contact($self->contact);

  $self->js->render();
}


sub _pre_render {
  my ($self) = @_;

  $self->{all_contact_titles} = SL::DB::Manager::ContactTitle->get_all_sorted();
  #foreach my $contact (@{ $self->{contacts} }) {
  #  if ($contact->cp_title && !grep {$contact->cp_title eq $_->description} @{$self->{all_contact_titles}}) {
  #    unshift @{$self->{all_contact_titles}}, (SL::DB::ContactTitle->new(description => $contact->cp_title));
  #  }
  #}

  $self->{all_contact_departments} = SL::DB::Manager::ContactDepartment->get_all_sorted();
  #foreach my $contact (@{ $self->{contacts} }) {
  #  if ($contact->cp_abteilung && !grep {$contact->cp_abteilung eq $_->description} @{$self->{all_contact_departments}}) {
  #    unshift @{$self->{all_contact_departments}}, (SL::DB::ContactDepartment->new(description => $contact->cp_abteilung));
  #  }
  #}

  $::request->{layout}->add_javascripts("$_.js") for qw (kivi.Contact);

  $self->_setup_form_action_bar;
}

sub _check_auth {
  my ($self, $action) = @_;

  my $has_edit_rights    = $::auth->assert('customer_vendor_edit',     1); # TODO fixme
  $self->user_has_edit_rights($has_edit_rights);

  if (!$has_edit_rights) {#$self->_may_access_action($action)) {
    $::auth->deny_access;
  }
}

sub init_contact {
  my ($self) = @_;

  $::form->{id} ? SL::DB::Contact->new(cp_id => $::form->{id})->load()
                : SL::DB::Contact->new(custom_variables => []);
}

sub _copy_form_to_cvars {
  my ($self, %params) = @_;

  foreach my $cvar (@{ $params{target}->cvars_by_config }) {
    my $value = $params{source}->{$cvar->config->name};
    $value    = $::form->parse_amount(\%::myconfig, $value) if $cvar->config->type eq 'number';

    $cvar->value($value);
  }
}

sub _instantiate_args {
  my ($self) = @_;

  $self->contact->assign_attributes(%{$::form->{contact}});
  $self->_copy_form_to_cvars(target => $self->contact, source => $::form->{contact_cvars});
}


sub _setup_form_action_bar {
  my ($self) = @_;

  my $no_rights = $self->user_has_edit_rights ? undef : t8("You don't have the rights to edit this contact.");

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => "Contact/save" } ],
        accesskey => 'enter',
        disabled  => $no_rights,
      ],

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => "Contact/delete" } ],
        confirm  => t8('Delete the contact? This will also remove the contact from all other customers and vendors.'),
        disabled => !$self->contact->cp_id ? t8('This object has not been saved yet.') : $no_rights,
      ],

      #action => [
      #  t8('History'),
      #  call     => [ 'kivi.CustomerVendor.showHistoryWindow', $self->{cv}->id ],
      #  disabled => !$self->{cv}->id ? t8('This object has not been saved yet.') : undef,
      #],
    );
  }
}



1;
