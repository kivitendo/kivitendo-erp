package SL::Controller::VariantProperty;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::DB::Manager::VariantProperty;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(variant_property) ]
);

#__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_javascripts', only => [ qw(edit_variant_property) ]);

#
# actions
#

sub action_list_variant_properties {
  my ($self) = @_;

  $self->_setup_list_action_bar;
  $self->render('variant_property/variant_property_list',
                title             => t8('Variant Property'),
                VARIANTPROPERTIES => SL::DB::Manager::VariantProperty->get_all_sorted,
               );
}

sub action_edit_variant_property {
  my ($self) = @_;

  my $is_new = !$self->variant_property->id;
  $self->_setup_form_action_bar;
  $self->render(
    'variant_property/variant_property_form',
    title => ($is_new ? t8('Add Variant Property') : t8('Edit Variant Property')),
  );
}

sub action_save_variant_property {
  my ($self) = @_;

  $self->create_or_update_variant_property;
}

sub action_delete_variant_property {
  my ($self) = @_;

  SL::DB->client->with_transaction(sub {
      $_->delete for $self->variant_property->property_values;
      $self->variant_property->delete;
      flash_later('info',  t8('The Variant Property has been deleted.'));
      1;
    }
  ) or flash_later('error', t8('The Variant Property is in use and cannot be deleted.'));
  $self->redirect_to(action => 'list_variant_properties');
}

sub action_reorder_variant_properties {
  my ($self) = @_;

  SL::DB::VariantProperty->reorder_list(@{ $::form->{variant_property_id} || [] });
  $self->render(\'', { type => 'json' }); # ' emacs happy again
}

sub action_reorder_variant_property_values {
  my ($self) = @_;

  SL::DB::VariantPropertyValue->reorder_list(@{ $::form->{variant_property_value_id} || [] });
  $self->render(\'', { type => 'json' }); # ' emacs happy again
}

sub action_edit_variant_property_value {
  my ($self) = @_;

  $self->js
    ->run(
      'kivi.VariantProperty.variant_property_value_dialog',
      t8('Variant Property Value'),
      $self->render(
        'variant_property/variant_property_value_form',
        { output => 0 },
        variant_property_value => SL::DB::Manager::VariantPropertyValue->find_by(
            id => $::form->{variant_property_value_id}
          ),
      )
    )
    ->reinit_widgets;

  $self->js->render;
}

sub action_save_variant_property_value {
  my ($self) = @_;

  die "'variant_property_value.id' is needed" unless $::form->{variant_property_value}->{id};

  my $variant_property_value = SL::DB::Manager::VariantPropertyValue->find_by(
    id => $::form->{variant_property_value}->{id}
  ) or die t8("Could not find Variant Property Value");

  $variant_property_value->update_attributes(
    %{$::form->{variant_property_value}}
  );

  flash_later('info', t8('The Variant Property Value has been saved.'));
  $self->redirect_to(
    action => 'edit_variant_property',
    id     => $variant_property_value->variant_property_id,
  );
}

sub action_delete_variant_property_value {
  my ($self) = @_;

  die "'variant_property_value.id' is needed" unless $::form->{variant_property_value}->{id};

  my $variant_property_value = SL::DB::Manager::VariantPropertyValue->find_by(
    id => $::form->{variant_property_value}->{id}
  ) or die t8("Could not find Variant Property Value");

  SL::DB->client->with_transaction(sub {
      $variant_property_value->delete;
      flash_later('info',
        t8(
          'The Variant Property Value \'#1\' has been deleted.',
          $variant_property_value->displayable_name
        )
      );
      1;
    }
  ) or flash_later('error',
    t8(
      'The Variant Property Value \'#1\' is in use and cannot be deleted.',
      $variant_property_value->displayable_name
    )
  );

  $self->redirect_to(
    action => 'edit_variant_property',
    id     => $variant_property_value->variant_property_id,
  );
}

sub action_add_variant_property_value {
  my ($self) = @_;

  my $new_variant_property_value = SL::DB::VariantPropertyValue->new(
    %{ $::form->{new_variant_property_value} },
    variant_property => $self->variant_property,
  )->save;

  $self->redirect_to(
    action => 'edit_variant_property',
    id     => $self->variant_property->id,
  );
}

#
#inits
#

sub init_variant_property {
  SL::DB::Manager::VariantProperty->find_by_or_create(id => $::form->{id} || 0)->assign_attributes(%{ $::form->{variant_property} });
}

sub add_javascripts  {
  $::request->{layout}->add_javascripts(qw(kivi.VariantProperty.js));
}

#
# helpers
#

sub create_or_update_variant_property {
  my ($self) = @_;

  my $is_new = !$self->variant_property->id;

  my @errors = $self->variant_property->validate;
  if (@errors) {
    flash('error', @errors);
    $self->action_edit_variant_property();
    return;
  }

  $self->variant_property->save;

  flash_later('info', $is_new ? t8('The Variant Property has been created.') : t8('The Variant Property has been saved.'));
  $self->redirect_to(
    action => 'edit_variant_property',
    id     => $self->variant_property->id,
  );
}

sub _setup_form_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => "VariantProperty/save_variant_property" } ],
          accesskey => 'enter',
        ],
         action => [
          t8('Delete'),
          submit => [ '#form', { action => "VariantProperty/delete_variant_property" } ],
          only_if => $self->variant_property->id,
        ],
      ],
      action => [
        t8('Cancel'),
        submit => [ '#form', { action => "VariantProperty/list_variant_properties" } ],
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
        link => $self->url_for(action => 'edit_variant_property'),
      ],
    )
  };
}

1;
