package SL::Controller::Pricegroup;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::DB::Manager::Pricegroup;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(pricegroup) ],
  'scalar --get_set_init' => [ qw(all_pricegroups) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_pricegroup', only => [ qw(edit update delete) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('pricegroup/list',
                title   => t8('Pricegroups'),
               );
}

sub action_new {
  my ($self) = @_;

  $self->pricegroup( SL::DB::Pricegroup->new );
  $self->render('pricegroup/form',
                 title => t8('Add pricegroup'),
               );
}

sub action_edit {
  my ($self) = @_;

  $self->render('pricegroup/form',
                 title   => t8('Edit pricegroup'),
                );
}

sub action_create {
  my ($self) = @_;

  $self->pricegroup( SL::DB::Pricegroup->new );
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  if ( !$self->pricegroup->orphaned ) {
    flash_later('error', $::locale->text('The pricegroup has been used and cannot be deleted.'));
  } elsif ( eval { $self->pricegroup->delete; 1; } ) {
    flash_later('info',  $::locale->text('The pricegroup has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The pricegroup has been used and cannot be deleted.'));
  };
  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::Pricegroup->reorder_list(@{ $::form->{pricegroup_id} || [] });
  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub load_pricegroup {
  my ($self) = @_;

  $self->pricegroup( SL::DB::Pricegroup->new(id => $::form->{id})->load );
}

sub init_all_pricegroups { SL::DB::Manager::Pricegroup->get_all_sorted }

#
# helpers
#

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->pricegroup->id;

  my $params = delete($::form->{pricegroup}) || { };

  $self->pricegroup->assign_attributes(%{ $params });

  my @errors = $self->pricegroup->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('pricegroup/form',
                   title => $is_new ? t8('Add pricegroup') : t8('Edit pricegroup'),
                 );
    return;
  }

  $self->pricegroup->save;

  flash_later('info', $is_new ? t8('The pricegroup has been created.') : t8('The pricegroup has been saved.'));
  $self->redirect_to(action => 'list');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Pricegroup - CRUD controller for pricegroups

=head1 SYNOPSIS

A new controller to create / edit / delete pricegroups.

Pricegroups can only be deleted if they haven't been used anywhere.

=head1 OBSOLETE PRICEGROUPS

Pricegroups can't be obsoleted while any of the customers still use that
pricegroup as their default pricegroup. Obsoleting a pricegroup means it can't
be selected when editing customers and it can't be selected as a price source
for new records.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
