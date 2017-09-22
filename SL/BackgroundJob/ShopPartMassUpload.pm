package SL::BackgroundJob::ShopPartMassUpload;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::DBUtils;
use SL::DB::ShopPart;
use SL::Shop;

use constant WAITING_FOR_EXECUTION        => 0;
use constant UPLOAD_TO_WEBSHOP            => 1;
use constant DONE                         => 2;

# Data format:
# my $data                  = {
#     shop_part_record_ids         => [ 603, 604, 605 ],
#     todo                         => $::form->{upload_todo},
#     status                       => SL::BackgroundJob::ShopPartMassUpload->WAITING_FOR_EXECUTION(),
#     num_uploaded                 => 0,
#     conversation                 => [ { id => 603 , number => 2, message => "Ok" or $@ }, ],
# };

sub update_webarticles {
  my ( $self ) = @_;

  my $job_obj = $self->{job_obj};
  my $db      = $job_obj->db;

  $job_obj->set_data(UPLOAD_TO_WEBSHOP())->save;
  my $num_uploaded = 0;
  foreach my $shop_part_id (@{ $job_obj->data_as_hash->{shop_part_record_ids} }) {
    my $data  = $job_obj->data_as_hash;
    eval {
      my $shop_part = SL::DB::Manager::ShopPart->find_by(id => $shop_part_id);
      unless($shop_part){
        push @{ $data->{conversion} }, { id => $shop_part_id, number => '', message => 'Shoppart not found' };
      }

      my $shop = SL::Shop->new( config => $shop_part->shop );

      my $return    = $shop->connector->update_part($shop_part, $data->{todo});
      if ( $return == 1 ) {
        my $now = DateTime->now;
        my $attributes->{last_update} = $now;
        $shop_part->assign_attributes(%{ $attributes });
        $shop_part->save;
        $data->{num_uploaded} = $num_uploaded++;
        push @{ $data->{conversion} }, { id => $shop_part_id, number => $shop_part->part->partnumber, message => 'uploaded' };
      }else{
      push @{ $data->{conversion} }, { id => $shop_part_id, number => $shop_part->part->partnumber, message => $return };
      }
      1;
    } or do {
      push @{ $data->{conversion} }, { id => $shop_part_id, number => '', message => $@ };
    };

    $job_obj->update_attributes(data_as_hash => $data);
  }
}

sub run {
  my ($self, $job_obj) = @_;

  $self->{job_obj}         = $job_obj;
  $self->update_webarticles;

  $job_obj->set_data(status => DONE())->save;

  return 1;
}
1;
