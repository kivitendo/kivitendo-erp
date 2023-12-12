package SL::Controller::VariantProperty;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::DB::Manager::VariantProperty;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(variant_property variant_property_value) ]
);

#__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_javascripts', only => [ qw(edit_property) ]);

#
# actions
#

sub action_list_properties {
  my ($self) = @_;

  $self->_setup_list_action_bar;
  $self->render('variant_property/variant_property_list',
                title             => t8('Variant Property'),
                VARIANTPROPERTIES => SL::DB::Manager::VariantProperty->get_all_sorted,
               );
}

sub action_edit_property {
  my ($self) = @_;

  my $is_new = !$self->variant_property->id;
  $self->_setup_form_action_bar;
  $self->render('variant_property/variant_property_form', title => ($is_new ? t8('Add Variant Property') : t8('Edit Variant Property')));
}

sub action_save_property {
  my ($self) = @_;

  $self->create_or_update_property;
}

sub action_delete_property {
  my ($self) = @_;

  if ( eval { $self->shop->delete; 1; } ) {
    flash_later('info',  $::locale->text('The shop has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The shop is in use and cannot be deleted.'));
  };
  $self->redirect_to(action => 'list_properties');
}

sub action_reorder_properties {
  my ($self) = @_;

  SL::DB::VariantProperty->reorder_list(@{ $::form->{variant_property_id} || [] });
  $self->render(\'', { type => 'json' }); # ' emacs happy again
}

sub action_edit_property_value {
  my ($self) = @_;

  $self->render_variant_edit_dialog();
}

sub action_save_property_value {
  my ($self) = @_;

  $self->create_or_update_property_value;
}


sub render_variant_edit_dialog {
  my ($self) = @_;
  $self->js
    ->run(
      'kivi.VariantProperty.variant_dialog',
      t8('Variant Value'),
      $self->render('variant_property/variant_property_value_form', { output => 0 })
    )
    ->reinit_widgets;

  $self->js->render;
}

#sub action_list_property_values_list {
#  my ($self) = @_;
#
#  $self->_setup_list_action_bar;
#  $self->render('variant_property/variant_property_list',
#                title             => t8('Variant Property'),
#                VARIANTPROPERTIES => SL::DB::Manager::VariantProperty->get_all_sorted,
#               );
#}

#sub action_reorder {
#  my ($self) = @_;
#
#  SL::DB::DeliveryTerm->reorder_list(@{ $::form->{delivery_term_id} || [] });
#
#  $self->render(\'', { type => 'json' });     # ' make Emacs happy
#}
#
#
#inits
#

sub init_variant_property {
  SL::DB::Manager::VariantProperty->find_by_or_create(id => $::form->{id} || 0)->assign_attributes(%{ $::form->{variant_property} });
}

sub init_variant_property_value {
  SL::DB::Manager::VariantPropertyValue->find_by_or_create(id => $::form->{variant_property_value_id} || 0)->assign_attributes(%{ $::form->{variant_property_value} });
}

sub add_javascripts  {
  $::request->{layout}->add_javascripts(qw(kivi.VariantProperty.js));
}

#
# helpers
#

sub create_or_update_property {
  my ($self) = @_;

  my $is_new = !$self->variant_property->id;

  my @errors = $self->variant_property->validate;
  if (@errors) {
    flash('error', @errors);
    $self->action_edit_property();
    return;
  }

  $self->variant_property->save;

  flash_later('info', $is_new ? t8('The Variant Property has been created.') : t8('The Variant Property has been saved.'));
  $self->redirect_to(action => 'list_properties');
}

sub create_or_update_property_value {
  my ($self) = @_;

  $main::lxdebug->dump(0, "TST:FORM ", $::form);
  my $is_new = !$self->variant_property_value->id;

#  my @errors = $self->variant_property_value->validate;
#  if (@errors) {
#    flash('error', @errors);
#    $self->action_edit_property();
#    return;
#  }
  $main::lxdebug->dump(0, "TST:PV ", $self->variant_property_value);
  $self->variant_property_value->assign_attributes( variant_property_id => $::form->{property_value_id});
  $self->variant_property_value->save;

  flash_later('info', $is_new ? t8('The Variant Property Value has been created.') : t8('The Variant Property Value has been saved.'));
  $self->action_edit_property();
  return;
}

sub _setup_form_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => "VariantProperty/save_property" } ],
          accesskey => 'enter',
        ],
         action => [
          t8('Delete'),
          submit => [ '#form', { action => "VariantProperty/delete_property" } ],
        ],
      ],
      action => [
        t8('Cancel'),
        submit => [ '#form', { action => "VariantProperty/list_properties" } ],
      ],
    );
  }
}

sub _setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link => $self->url_for(action => 'edit_property'),
      ],
    )
  };
}

1;
