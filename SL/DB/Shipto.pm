package SL::DB::Shipto;

use strict;
use Readonly;

use SL::DB::MetaSetup::Shipto;

Readonly our @SHIPTO_VARIABLES => qw(shiptoname shiptostreet shiptozipcode shiptocity shiptocountry shiptocontact
                                     shiptophone shiptofax shiptoemail shiptodepartment_1 shiptodepartment_2);

__PACKAGE__->meta->make_manager_class;

sub displayable_id {
  my $self = shift;
  my $text = join('; ', grep { $_ } (map({ $self->$_ } qw(shiptoname shiptostreet)),
                                     join(' ', grep { $_ }
                                               map  { $self->$_ }
                                               qw(shiptozipcode shiptocity))));

  return $text;
}

1;
