package SL::Controller::PartsGroup;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::PartsGroup;
use SL::Helper::Flash;
use SL::Locale::String;
use List::MoreUtils qw(any);

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(partsgroup) ],
  # 'scalar --get_set_init' => [ qw(defaults) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_partsgroup', only => [ qw(edit update delete) ]);

sub check_auth {
  $::auth->assert('config');
}

#
# actions
#

sub action_list {
  my ($self, %params) = @_;

  $self->setup_list_action_bar;
  $self->render('partsgroup/list',
                 title => $::locale->text('Partsgroups'),
                 PARTSGROUPS => SL::DB::Manager::PartsGroup->get_hierarchy,
               );
}

sub action_sort_roots {
  my ($self) = @_;

  # Only for sorting the root partsgroup, and adding new ones.
  # The simple arrows don't work on the main hierarchy view, if all subgroups
  # are also shown. You would need a proper drag&drop Module for this.

  my @root_partsgroups = grep { $_->{level} == 0 } @{ SL::DB::Manager::PartsGroup->get_hierarchy };

  $self->setup_show_sort_action_bar;
  $self->render(
    'partsgroup/sort_roots',
    title       => t8('Edit partsgroups'),
    PARTSGROUPS => \@root_partsgroups,
  );
}

sub action_new {
  my ($self) = @_;

  $self->partsgroup(SL::DB::PartsGroup->new());
  $self->show_form(title => t8('Add partsgroup'));
}

sub action_edit {
  my ($self) = @_;

  $self->show_form(title       => t8('Edit partsgroup'),
                   PARTSGROUPS => SL::DB::Manager::PartsGroup->get_hierarchy, # for dropsdown to move parts
                   PARTS       => $self->partsgroup->parts,
                  );
}

sub action_create {
  my ($self) = @_;

  $self->partsgroup(SL::DB::PartsGroup->new());
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;

  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  $self->partsgroup->db->with_transaction(sub {
    $self->partsgroup->delete();
    flash_later('info',  $::locale->text('The partsgroup has been deleted.'));

    1;
  }) || flash_later('error', $::locale->text('The partsgroup is in use and cannot be deleted.'));

  $self->redirect_to(action => 'list');
}

#
# ajax actions
#

sub action_reorder {
  my ($self) = @_;

  SL::DB::PartsGroup->reorder_list(@{ $::form->{partsgroup_id} || [] });

  $self->render(\'', { type => 'json' });
}

sub action_add_partsgroup {
  my ($self) = @_;

  unless ( $::form->{partsgroup_name} ) {
    return $self->js->flash('error', t8("The name must not be empty."))
                    ->render;
  };

  # check that name doesn't already exist in this grouping, catch before db constraint
  if ( SL::DB::Manager::PartsGroup->get_all_count(
    where => [ parent_id  => $::form->{parent_id} // undef,
               partsgroup => $::form->{partsgroup_name},
             ]) ) {
    return $self->js->flash('error', t8("A partsgroup with this name already exists."))
                    ->focus('#new_partsgroup')
                    ->render;
  };

  my %partsgroup_params = (
    partsgroup => $::form->{partsgroup_name},
  );

  $partsgroup_params{parent_id} = $::form->{parent_id} if $::form->{parent_id};

  my $new_partsgroup = SL::DB::PartsGroup->new(%partsgroup_params);
  $new_partsgroup->add_to_list(position => 'last');

  $self->_render_subgroups_table_body;
  return $self->js->val('#new_partsgroup', '')
                  ->flash('info', t8("Added partsgroup."))
                  ->focus('#new_partsgroup')
                  ->render;
}


sub action_add_part {
  my ($self) = @_;

  $main::lxdebug->dump(0, "add_part form", $::form );

  return $self->js->flash('error', t8("No part was selected."))->render
    unless $::form->{part_id};

  my $number_of_updated_parts = SL::DB::Manager::Part->update_all (
    set   => { partsgroup_id => $::form->{partsgroup_id} },
    where => [ id => $::form->{part_id},
               '!partsgroup_id' => $::form->{partsgroup_id}, # ignore updating to same partsgroup_id
             ]
  );

  if ( $number_of_updated_parts == 1 ) {
    $self->_render_parts_table_body; # needs $::form->{partsgroup_id}
    return $self->js->val('#add_part_id', undef)
                    ->val('#add_part_id_name', '')
                    ->flash('info', t8("Added part to partsgroup."))
                    ->render;
  } else {
    return $self->js->flash('error', t8("Part wasn't added to partsgroup!"))->render;
  }
}

sub action_update_partsgroup_for_parts{
  my ($self) = @_;

  $main::lxdebug->dump(0, "update_partsgroup", $::form );

  # change type and design of existing parts to an existing part_variant
  # updates part_variant_map entries and lemper_part.type_id and lemper_part.design

  # the id of the partsgroup we are moving parts from is $::form->{current_partsgroup_id}

  return $self->js->flash('error', t8("No parts selected."))->render      unless $::form->{part_ids};
  return $self->js->flash('error', t8("No partsgroup selected."))->render unless $::form->{selected_partsgroup_id};

  # don't delete partsgroup ids from form, needed by _render_parts_table_body
  # TODO: better error handling than die, use flash?
  my $partsgroup = SL::DB::Manager::PartsGroup->find_by(         id => $::form->{selected_partsgroup_id} ) // die 'selected partsgroup id not valid';
  my $current_partsgroup = SL::DB::Manager::PartsGroup->find_by( id => $::form->{current_partsgroup_id} )  // die 'not a valid partsgroup id';

  my $part_ids = $::form->{part_ids} // undef;
  if ( scalar @{ $part_ids } ) {
    my $parts_updated_count = 0;
    $current_partsgroup->db->with_transaction(sub {
      $parts_updated_count = SL::DB::Manager::Part->update_all (
        set   => { partsgroup_id => $partsgroup->id },
        where => [ id => $part_ids,
                   # partsgroup_id => $current_partsgroup->id
                 ], # what if one of them has changed in the meantime due to concurrent edits? should it fail? Currently
      );
      1;
    }) or return $self->js->error(t8('The parts couldn\'t be updated!') . ' ' . $current_partsgroup->db->error )->render;
    if ( $parts_updated_count == 1 ) {
      $self->js->flash('info', t8("Moved #1 part.", $parts_updated_count));
    } else {
      $self->js->flash('info', t8("Moved #1 parts.", $parts_updated_count));
    }
  } else {
    $self->js->flash('error', t8("No parts selected"));
  }

  $self->_render_parts_table_body; # needs $::form->{current_partsgroup_id}
  return $self->js->render;
}

#
# action bars
#

sub setup_show_form_action_bar {
  my ($self) = @_;

  my $is_new = !$self->partsgroup->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'PartsGroup/' . ($is_new ? 'create' : 'update') } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'PartsGroup/delete' } ],
        confirm  => t8('Do you really want to delete this partsgroup?'),
        disabled => $is_new                      ? t8('This partsgroup has not been saved yet.')
                  : !$self->partsgroup->orphaned ? t8('The partsgroup is in use and cannot be deleted.')
                  :                            undef,
      ],

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list'),
      ],
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link => $self->url_for(action => 'new'),
      ],
      link => [
        t8('Sort'),
        link => $self->url_for(action => 'sort_roots'),
      ],
    );
  }
}

sub setup_show_sort_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Partsgroups'),
        link => $self->url_for(action => 'list'),
      ],
    );
  }
}
#
# helpers
#

sub _render_subgroups_table_body {
  my ($self) = @_;

  my ($partsgroup, $partsgroups);
  if ( $::form->{parent_id} ) {
    $partsgroup  = SL::DB::PartsGroup->new(id => $::form->{parent_id})->load;
    $partsgroups = $partsgroup->children_sorted;
  } else {
    $partsgroups = SL::DB::Manager::PartsGroup->get_all(where => [ parent_id => undef ], sort_by => ('sortkey'));
    $main::lxdebug->message(0, "found " . scalar @{ $partsgroups } . " roots");
  }

  my $html      = $self->render('partsgroup/_subgroups_table_body', { output => 0 }, CHILDREN => $partsgroups);

  $self->js->html('#subgroups_table_body', $html);
}


sub _render_parts_table_body {
  my ($self) = @_;

  # May be called when items are added to the current partsgroup
  #   (action_add_part with $::form->{partsgroup_id}
  # or after items are moved away to other partsgroups
  #   (action_update_partsgroup_for_parts with $::form->{current_partsgroup_id})
  my $parts = SL::DB::Manager::Part->get_all(
    where => [ partsgroup_id =>    $::form->{current_partsgroup_id}
                                // $::form->{partsgroup_id}
             ]
  );
  my $html      = $self->render('partsgroup/_parts_table_body', { output => 0 }, PARTS => $parts);
  $self->js->html('#parts_table_body', $html);
}

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->partsgroup->id;

  my $params = delete($::form->{partsgroup}) || { };

  delete $params->{id};

  # parent_id needs additional checks
  # If the parent_id was changed the new parent_id mustn't have the current
  # parent_id as its ancestor, otherwise this would introdouce cycles in the
  # tree.
  # run this to prevent $params->{parent_id} to be used for assign_attributes

  my $old_parent_id = $self->partsgroup->parent_id; # may be undef
  my $new_parent_id = delete $params->{parent_id} || undef; # empty string/select will become undef

  my @errors;

  my $db = $self->partsgroup->db;
  if (!$db->with_transaction(sub {

    # assign attributes and validate
    $self->partsgroup->assign_attributes( %{$params} ) ;
    push(@errors, $self->partsgroup->validate); # check for description

    if (@errors) {
      die @errors . "\n";
    };

    if (    ( $old_parent_id == $new_parent_id )
         or ( !defined $old_parent_id && ! defined $new_parent_id )
       ) {
      # parent_id didn't change
      $self->partsgroup->save;

    } elsif (    ( $old_parent_id != $new_parent_id )
              or ( not defined $old_parent_id && $new_parent_id )
              or ( $old_parent_id && not defined $new_parent_id) # setting parent to undef is always allowed!
            ) {
      # parent_id has changed, check for cycles
      my $ancestor_ids = SL::DB::PartsGroup->new(id => $new_parent_id)->ancestor_ids;

      if ( any { $self->partsgroup->id == $_ } @{$ancestor_ids} ) {
        die "Error: This would introduce a cycle, new parent must not be a subparent\n";
      };
      $self->partsgroup->remove_from_list;
      $self->partsgroup->parent_id($new_parent_id);
      $self->partsgroup->add_to_list(position => 'last');
    }

    1;
  })) {
    die @errors ? join("\n", @errors) . "\n" : $db->error . "\n";
  }

  flash_later('info', $is_new ? t8('The partsgroup has been created.') : t8('The partsgroup has been saved.'));
  $self->redirect_to(action => 'list');
}

sub show_form {
  my ($self, %params) = @_;

  $self->setup_show_form_action_bar;
  $self->render('partsgroup/form', %params,
               );
}

sub load_partsgroup {
  my ($self) = @_;

  $self->partsgroup(SL::DB::PartsGroup->new(id => $::form->{id})->load);
}

1;
