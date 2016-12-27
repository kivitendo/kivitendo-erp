package SL::Controller::DownloadZip;

use strict;

use parent qw(SL::Controller::Base);

use List::Util qw(first max);

use utf8;
use Encode qw(decode encode);
use Archive::Zip;
use SL::File;
use SL::SessionFile::Random;

sub action_download_orderitems_files {
  my ($self) = @_;

  #
  # special case for customer which want to have not all
  # in kivitendo.conf some regex may be defined:
  # For no values just let it commented out
  # PA = Produktionsauftrag, L = Lieferschein, ML = Materialliste
  # If you want several options, please seperate the letter with '|'. Example: '^(PA|L).*'
  #set_sales_documenttype_for_delivered_quantity = '^(LS).*'
  #set_purchase_documenttype_for_delivered_quantity = '^(EL).*'
  #
  # enbale this perl code:
  #  my $doctype = $::lx_office_conf{system}->{"set_documenttype_for_part_zip_download"};
  #  if ( $doctype ) {
  #    # eliminate first and last char (are quotes)
  #    $doctype =~ s/^.//;
  #    $doctype =~ s/.$//;
  #  }

  #$Archive::Zip::UNICODE = 1;

  my $object_id    = $::form->{object_id};
  my $object_type  = $::form->{object_type};
  my $element_type = $::form->{element_type};
  my $sfile = SL::SessionFile::Random->new(mode => "w");
  my $zip = Archive::Zip->new();
  #TODO Check client encoding !!
  #my $name_encoding = 'cp850';
  my $name_encoding = 'UTF-8';

  # today only sales_order implementation !
  if ( $object_id && $object_type eq 'sales_order' && $element_type eq 'part' ) {
    my $orderitems = SL::DB::Manager::OrderItem->get_all(query => ['order.id' => $object_id ],
                                                         with_objects => [ 'order', 'part' ],
                                                         sort_by => 'part.partnumber ASC');
    my $part_id = 0;
    foreach my $item ( @{$orderitems} ) {
      next if $part_id == $item->parts_id;

      my @files = SL::File->get_all(object_id   => $item->parts_id,
                                    object_type => $element_type,
                                  );
      my @wanted_files;
      ## also for filtering if needed:
      # if ( $doctype ) {
      #   @wanted_files = grep { $_->{file_name} =~ /$doctype/ } @files;
      # } else {
      @wanted_files = @files;
      # }
      if ( scalar (@wanted_files) > 0 ) {
        $zip->addDirectory($item->part->partnumber);
        $zip->addFile(SL::File->get_file_path(dbfile => $_ ),
                      Encode::encode($name_encoding,$item->part->partnumber.'/'.$_->{file_name})
                      ) for @wanted_files;
      }
    }
  }
  unless ( $zip->writeToFileNamed($sfile->file_name) == Archive::Zip::AZ_OK ) {
    die 'zipfile write error';
  }
  $sfile->fh->close;

  return $self->send_file(
    $sfile->file_name,
    type => 'application/zip',
    name => $::form->{zipname}.'.zip',
  );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Controller::DownloadZip - controller for download all files from parts of an order in one zip file

=head2  C<action_download_zip FORMPARAMS>

Some customer want all attached files for the parts of an sales order or sales delivery order in one zip to download.
This is a special method for one customer, so it is moved into an extra controller.
The $Archive::Zip::UNICODE = 1; doesnt work ok
So today the filenames in cp850/DOS format for legacy windows.
To ues it for Linux Clients an additinal effort must be done,
for ex. a link to the same file with an utf-8 name.

There is also a special javascript method necessary which calles this controller method.
THis method must be inserted into the customer branch:

=begin text

  ns.downloadOrderitemsAtt = function(type,id) {
    var rowcount  = $('input[name=rowcount]').val() - 1;
	  var data = {
        action:     'FileManagement/download_zip',
        type:       type,
        object_id:  id,
        rowcount:   rowcount
    };
    if ( rowcount == 0 ) {
        kivi.display_flash('error', kivi.t8('No articles have been added yet.'));
        return false; 
    }
    for (var i = 1; i <= rowcount; i++) {
        data['parts_id_'+i] =  $('#id_' + i).val();
    };
    $.download("controller.pl", data);
    return false;
  }

=end text

See also L<SL::Controller::FileManagement>

=head1 DISCUSSION

Is this method needed in the master branch ?

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
