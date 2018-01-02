package SL::DB::GLTransaction;

use strict;

use SL::DB::MetaSetup::GLTransaction;
use SL::Locale::String qw(t8);
use List::Util qw(sum);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->add_relationship(
  transactions   => {
    type         => 'one to many',
    class        => 'SL::DB::AccTransaction',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'chart' ],
      sort_by      => 'acc_trans_id ASC',
    },
  },
);

__PACKAGE__->meta->initialize;

sub abbreviation {
  my $self = shift;

  my $abbreviation = $::locale->text('GL Transaction (abbreviation)');
  $abbreviation   .= "(" . $::locale->text('Storno (one letter abbreviation)') . ")" if $self->storno;
  return $abbreviation;
}

sub displayable_type {
  return t8('GL Transaction');
}

sub oneline_summary {
  my ($self) = @_;
  my $amount =  sum map { $_->amount if $_->amount > 0 } @{$self->transactions};
  $amount = $::form->format_amount(\%::myconfig, $amount, 2);
  return sprintf("%s: %s %s %s (%s)", $self->abbreviation, $self->description, $self->reference, $amount, $self->transdate->to_kivitendo);
}

sub link {
  my ($self) = @_;

  my $html;
  $html   = $self->presenter->gl_transaction(display => 'inline');

  return $html;
}

sub invnumber {
  return $_[0]->reference;
}

sub date { goto &gldate }

1;
