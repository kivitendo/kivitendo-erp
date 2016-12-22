package SL::Controller::PartClassification;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::PartClassification;
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(part_classification) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_part_classification', only => [ qw(edit update destroy) ]);

#
# This Controller is responsible for creating,editing or deleting
# Part Classifications.
#
# The use of Part Classifications is described in SL::DB::PartClassification
#
#

# List all available part classifications
#

sub action_list {
  my ($self) = @_;

  $self->render('part_classification/list',
                title                => $::locale->text('Parts Classifications'),
                PART_CLASSIFICATIONS => SL::DB::Manager::PartClassification->get_all_sorted);
}

# A Form for a new creatable part classifications is generated
#
sub action_new {
  my ($self) = @_;

  $self->{part_classification} = SL::DB::PartClassification->new;
  $self->render('part_classification/form', title => $::locale->text('Create a new parts classification'));
}

# Edit an existing part classifications
#
sub action_edit {
  my ($self) = @_;
  $self->render('part_classification/form', title => $::locale->text('Edit parts classification'));
}

# A new part classification is saved
#
sub action_create {
  my ($self) = @_;

  $self->{part_classification} = SL::DB::PartClassification->new;
  $self->create_or_update;
}

# An existing part classification is saved
#
sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

# An existing part classification is deleted
#
# The basic classifications cannot be deleted, also classifications which are in use
#
sub action_destroy {
  my ($self) = @_;

  if ( $self->{part_classification}->id < 5 ) {
    flash_later('error', $::locale->text('The basic parts classification cannot be deleted.'));
  }
  elsif (eval { $self->{part_classification}->delete; 1; }) {
    flash_later('info',  $::locale->text('The parts classification has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The parts classification is in use and cannot be deleted.'));
  }

  $self->redirect_to(action => 'list');
}
# reordering the lines
#
sub action_reorder {
  my ($self) = @_;

  SL::DB::PartClassification->reorder_list(@{ $::form->{part_classification_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

# check authentication, only "config" is allowed
#
sub check_auth {
  $::auth->assert('config');
}

#
# helpers
#

# submethod for update the database
#
sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->{part_classification}->id;

  $::form->{part_classification}->{used_for_purchase} = 0 if ! $::form->{part_classification}->{used_for_purchase};
  $::form->{part_classification}->{used_for_sale}     = 0 if ! $::form->{part_classification}->{used_for_sale};
  $::form->{part_classification}->{report_separate}   = 0 if ! $::form->{part_classification}->{report_separate};

  my $params = delete($::form->{part_classification}) || { };

  $self->{part_classification}->assign_attributes(%{ $params });

  my @errors = $self->{part_classification}->validate;

  if (@errors) {
    flash('error', @errors);
    $self->render('part_classification/form', title => $is_new ? $::locale->text('Create a new parts classification') : $::locale->text('Edit parts classification'));
    return;
  }

  $self->{part_classification}->save;

  flash_later('info', $is_new ? $::locale->text('The parts classification has been created.') : $::locale->text('The parts classification has been saved.'));
  $self->redirect_to(action => 'list');
}

# submethod for loading one item from the database
#
sub load_part_classification {
  my ($self) = @_;
  $self->{part_classification} = SL::DB::PartClassification->new(id => $::form->{id})->load;
}

1;



__END__

=encoding utf-8

=head1 NAME

SL::Controller::PartClassification

=head1 SYNOPSIS

This Controller is responsible for creating,editing or deleting
Part Classifications.

=head1 DESCRIPTION

The use of Part Classifications is described in L<SL::DB::PartClassification>

=head1 METHODS

=head2 action_create

 $self->action_create();

A new part classification is saved



=head2 action_destroy

 $self->action_destroy();

An existing part classification is deleted

The basic classifications cannot be deleted, also classifications which are in use



=head2 action_edit

 $self->action_edit();

Edit an existing part classifications



=head2 action_list

 $self->action_list();

List all available part classifications



=head2 action_new

 $self->action_new();

A Form for a new creatable part classifications is generated



=head2 action_reorder

 $self->action_reorder();

reordering the lines



=head2 action_update

 $self->action_update();

An existing part classification is saved


=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
