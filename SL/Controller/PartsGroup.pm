package SL::Controller::PartsGroup;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::DB::Manager::PartsGroup;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(partsgroup) ],
  'scalar --get_set_init' => [ qw(all_partsgroups) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_partsgroup', only => [ qw(edit update delete) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('partsgroup/list',
                title   => t8('Partsgroups'),
               );
}

sub action_new {
  my ($self) = @_;

  $self->partsgroup( SL::DB::PartsGroup->new );
  $self->render('partsgroup/form',
                 title => t8('Add partsgroup'),
               );
}

sub action_edit {
  my ($self) = @_;

  $self->render('partsgroup/form',
                 title   => t8('Edit partsgroup'),
                );
}

sub action_create {
  my ($self) = @_;

  $self->partsgroup( SL::DB::PartsGroup->new );
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  if ( !$self->partsgroup->orphaned ) {
    flash_later('error', $::locale->text('The partsgroup has been used and cannot be deleted.'));
  } elsif ( eval { $self->partsgroup->delete; 1; } ) {
    flash_later('info',  $::locale->text('The partsgroup has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The partsgroup has been used and cannot be deleted.'));
  };
  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::PartsGroup->reorder_list(@{ $::form->{partsgroup_id} || [] });
  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub load_partsgroup {
  my ($self) = @_;

  $self->partsgroup( SL::DB::PartsGroup->new(id => $::form->{id})->load );
}

sub init_all_partsgroups { SL::DB::Manager::PartsGroup->get_all_sorted }

#
# helpers
#

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->partsgroup->id;

  my $params = delete($::form->{partsgroup}) || { };

  $self->partsgroup->assign_attributes(%{ $params });

  my @errors = $self->partsgroup->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('partsgroup/form',
                   title => $is_new ? t8('Add partsgroup') : t8('Edit partsgroup'),
                 );
    return;
  }

  $self->partsgroup->save;

  flash_later('info', $is_new ? t8('The partsgroup has been created.') : t8('The partsgroup has been saved.'));
  $self->redirect_to(action => 'list');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::PartsGroup - CRUD controller for partsgroups

=head1 SYNOPSIS

A new controller to create / edit / delete partsgroups.

Partsgroups can only be deleted if they haven't been used anywhere.

=head1 OBSOLETE PARTSGROUPS

A partsgroup can be deleted if it hasn't been used anywhere / is orphaned.

A partsgroup can be set to obsolete, which means new items can't be assigned
that partsgroup, but old items with that partsgroup can keep it. And you can
also still filter for these obsolete partsgroups in reports.

=head1 ISSUES

Unlike the old version (pe.pl/PE.pm), there is no way to filter/search the
partsgroups in the overview page, it always shows the complete (ordered) list,
ordered by sortkey.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
