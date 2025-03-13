package SL::Controller::File;

use strict;

use parent qw(SL::Controller::Base);

use List::Util qw(first max);

use utf8;
use Encode qw(decode);
use English qw( -no_match_vars );
use URI::Escape;
use Cwd;
use DateTime;
use File::stat;
use File::Slurp qw(slurp);
use File::Spec::Unix;
use File::Spec::Win32;
use File::MimeInfo::Magic;
use MIME::Base64;
use SL::DB::Helper::Mappings;
use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Invoice;

use SL::DB::PurchaseInvoice;
use SL::DB::Part;
use SL::DB::GLTransaction;
use SL::DB::Draft;
use SL::DB::History;
use SL::JSON;
use SL::Helper::CreatePDF qw(:all);
use SL::Locale::String;
use SL::SessionFile;
use SL::SessionFile::Random;
use SL::File;
use SL::Controller::Helper::ThumbnailCreator qw(file_probe_image_type file_probe_type);

use constant DO_DELETE   => 0;
use constant DO_UNIMPORT => 1;

use Rose::Object::MakeMethods::Generic
(
    'scalar --get_set_init' => [ qw() ],
    'scalar' => [ qw(object object_type object_model object_id object_right file_type files is_global existing) ],
);

__PACKAGE__->run_before('check_object_params', only => [ qw(list ajax_delete ajax_importdialog ajax_import ajax_unimport ajax_upload ajax_files_uploaded) ]);

# gen:    bitmask: bit 1 (value is 1, 3, 5 or 7) => file created
#                  bit 2 (value is 2, 3, 6 or 7) => file from other source (e.g. directory for scanned documents)
#                  bit 3 (value is 4, 5, 6 or 7) => upload as other source
# gltype: is this used somewhere?
# dir:    is this used somewhere?
# model:  base name of the rose model
# right:  access right used for import
my %file_types = (
  'sales_quotation'             => { gen => 7, gltype => '',   dir =>'SalesQuotation',            model => 'Order',          right => 'import_ar'  },
  'sales_order_intake'          => { gen => 7, gltype => '',   dir =>'SalesOrderIntake',          model => 'Order',          right => 'import_ar'  },
  'sales_order'                 => { gen => 7, gltype => '',   dir =>'SalesOrder',                model => 'Order',          right => 'import_ar'  },
  'sales_delivery_order'        => { gen => 7, gltype => '',   dir =>'SalesDeliveryOrder',        model => 'DeliveryOrder',  right => 'import_ar'  },
  'sales_reclamation'           => { gen => 7, gltype => '',   dir =>'SalesReclamation',          model => 'Reclamation',    right => 'import_ar'  },
  'invoice'                     => { gen => 7, gltype => 'ar', dir =>'SalesInvoice',              model => 'Invoice',        right => 'import_ar'  },
  'invoice_for_advance_payment' => { gen => 7, gltype => 'ar', dir =>'SalesInvoice',              model => 'Invoice',        right => 'import_ar'  },
  'final_invoice'               => { gen => 7, gltype => 'ar', dir =>'SalesInvoice',              model => 'Invoice',        right => 'import_ar'  },
  'credit_note'                 => { gen => 7, gltype => '',   dir =>'CreditNote',                model => 'Invoice',        right => 'import_ar'  },
  'request_quotation'           => { gen => 7, gltype => '',   dir =>'RequestForQuotation',       model => 'Order',          right => 'import_ap'  },
  'purchase_quotation_intake'   => { gen => 7, gltype => '',   dir =>'PurchaseQuotationIntake',   model => 'Order',          right => 'import_ap'  },
  'purchase_order'              => { gen => 7, gltype => '',   dir =>'PurchaseOrder',             model => 'Order',          right => 'import_ap'  },
  'purchase_order_confirmation' => { gen => 7, gltype => '',   dir =>'PurchaseOrderConfirmation', model => 'Order',          right => 'import_ap'  },
  'purchase_delivery_order'     => { gen => 7, gltype => '',   dir =>'PurchaseDeliveryOrder',     model => 'DeliveryOrder',  right => 'import_ap'  },
  'purchase_reclamation'        => { gen => 7, gltype => '',   dir =>'PurchaseReclamation',       model => 'Reclamation',    right => 'import_ap'  },
  'purchase_invoice'            => { gen => 7, gltype => 'ap', dir =>'PurchaseInvoice',           model => 'PurchaseInvoice',right => 'import_ap'  },
  'supplier_delivery_order'     => { gen => 7, gltype => '',   dir =>'SupplierDeliveryOrder',     model => 'DeliveryOrder',  right => 'import_ap'  },
  'rma_delivery_order'          => { gen => 7, gltype => '',   dir =>'RMADeliveryOrder',          model => 'DeliveryOrder',  right => 'import_ar'  },
  'vendor'                      => { gen => 0, gltype => '',   dir =>'Vendor',                    model => 'Vendor',         right => 'xx'         },
  'customer'                    => { gen => 1, gltype => '',   dir =>'Customer',                  model => 'Customer',       right => 'xx'         },
  'project'                     => { gen => 0, gltype => '',   dir =>'Project',                   model => 'Project',        right => 'xx'         },
  'part'                        => { gen => 0, gltype => '',   dir =>'Part',                      model => 'Part',           right => 'xx'         },
  'gl_transaction'              => { gen => 6, gltype => 'gl', dir =>'GeneralLedger',             model => 'GLTransaction',  right => 'import_ap'  },
  'draft'                       => { gen => 0, gltype => '',   dir =>'Draft',                     model => 'Draft',          right => 'xx'         },
  'csv_customer'                => { gen => 1, gltype => '',   dir =>'Reports',                   model => 'Customer',       right => 'xx'         },
  'csv_vendor'                  => { gen => 1, gltype => '',   dir =>'Reports',                   model => 'Vendor',         right => 'xx'         },
  'shop_image'                  => { gen => 0, gltype => '',   dir =>'ShopImages',                model => 'Part',           right => 'xx'         },
  'letter'                      => { gen => 7, gltype => '',   dir =>'Letter',                    model => 'Letter',         right => 'sales_letter_edit | purchase_letter_edit' },
);

#--- 4 locale ---#
# $main::locale->text('imported')

#
# actions
#

sub action_list {
  my ($self) = @_;

  my $is_json = 0;
  $is_json = 1 if $::form->{json};

  $self->_do_list($is_json);
}

sub action_ajax_importdialog {
  my ($self) = @_;
  $::auth->assert($self->object_right);
  my $path   = $::form->{path};
  my @files  = $self->_get_from_import($path);
  my $source = {
    'name'         => $::form->{source},
    'path'         => $path ,
    'chk_action'   => $::form->{source}.'_import',
    'chk_title'    => $main::locale->text('Import scanned documents'),
    'chkall_title' => $main::locale->text('Import all'),
    'files'        => \@files
  };
  $self->render('file/import_dialog',
                { layout => 0
                },
                source => $source
  );
}

sub action_ajax_import {
  my ($self) = @_;
  $::auth->assert($self->object_right);
  my $ids    = $::form->{ids};
  my $source = $::form->{source};
  my $path   = $::form->{path};
  my @files  = $self->_get_from_import($path);
  foreach my $filename (@{ $::form->{$ids} || [] }) {
    my ($file, undef) = grep { $_->{name} eq $filename } @files;
    if ( $file ) {
      my $obj = SL::File->save(object_id   => $self->object_id,
                               object_type => $self->object_type,
                               mime_type   => 'application/pdf',
                               source      => $source,
                               file_type   => 'document',
                               file_name   => $file->{filename},
                               file_path   => $file->{path}
                             );
      unlink($file->{path}) if $obj;
    }
  }
  $self->_do_list(1);
}

sub action_ajax_delete {
  my ($self) = @_;
  $self->_delete_all(DO_DELETE, $::locale->text('Following files are deleted:'));
}

sub action_ajax_unimport {
  my ($self) = @_;
  $self->_delete_all(DO_UNIMPORT, $::locale->text('Following files are unimported:'));
}

sub action_ajax_rename {
  my ($self) = @_;
  my $guid = $::form->{id};
  my $file = SL::File->get(guid => $guid);
  if ( ! $file ) {
    $self->js->flash('error', $::locale->text('File not exists !'))->render();
    return;
  }
  my $sessionfile = $::form->{sessionfile};
  if ( $sessionfile && -f $sessionfile ) {
    # new uploaded file
    if ( $::form->{to} eq $file->file_name ) {
      # no rename so use as new version
      $file->save_file($sessionfile);
      $self->js->flash('warning', $::locale->text('File \'#1\' is used as new Version !', $file->file_name));

    } else {
      # new filename, so it is a new file with the same attributes as the old file
      eval {
        SL::File->save(object_id   => $file->object_id,
                       object_type => $file->object_type,
                       mime_type   => $file->mime_type,
                       source      => $file->source,
                       file_type   => $file->file_type,
                       file_name   => $::form->{to},
                       file_path   => $sessionfile
                     );
        unlink($sessionfile);
        1;
      } or do {
        $self->js
          ->flash('error', t8('internal error (see details)'), $@)
          ->render;
        return;
      }
    }

  } else {
    # normal rename
    my $result;

    eval {
      $result = $file->rename($::form->{to});
      1;
    } or do {
      $self->js
        ->flash('error', t8('internal error (see details)'), $@)
        ->render;
      return;
    };

    if ($result != SL::File::RENAME_OK) {
      $self->js->flash('error',
                         $result == SL::File::RENAME_EXISTS ? $::locale->text('File still exists !')
                       : $result == SL::File::RENAME_SAME   ? $::locale->text('Same Filename !')
                       :                                      $::locale->text('File not exists !'))
        ->render;
      return;
    }
  }
  $self->is_global($::form->{is_global});
  $self->file_type(  $file->file_type);
  $self->object_type($file->object_type);
  $self->object_id(  $file->object_id);
  #$self->object_model($file_types{$file->module}->{model});
  #$self->object_right($file_types{$file->module}->{right});
  if ( $::form->{next_ids} ) {
    my @existing = split(/,/, $::form->{next_ids});
    $self->existing(\@existing);
  }
  $self->_do_list(1);
}

sub action_ajax_upload {
  my ($self) = @_;
  $self->{maxsize} = $::instance_conf->get_doc_max_filesize;
  $self->{accept_types} = '';
  $self->{accept_types} = 'image/png,image/gif,image/jpeg,image/tiff,*png,*gif,*.jpg,*.tif' if $self->{file_type} eq 'image';
  $self->render('file/upload_dialog',
                { layout => 0
                },
  );
}

sub action_ajax_files_uploaded {
  my ($self) = @_;

  my $source = 'uploaded';
  my @existing;
  if ( $::form->{ATTACHMENTS}->{uploadfiles} ) {
    my @upfiles = @{ $::form->{ATTACHMENTS}->{uploadfiles} };
    foreach my $idx (0 .. scalar(@upfiles) - 1) {
      eval {
        my $fname = uri_unescape($upfiles[$idx]->{filename});
        # normalize and find basename
        # first split with unix rules
        # after that split with windows rules
        my ($volume, $directories, $basefile) = File::Spec::Unix->splitpath($fname);
        ($volume, $directories, $basefile) = File::Spec::Win32->splitpath($basefile);

        # to find real mime_type by magic we must save the filedata

        my $sess_fname = "file_upload_" . $self->object_type . "_" . $self->object_id . "_" . $idx;
        my $sfile      = SL::SessionFile->new($sess_fname, mode => 'w');

        $sfile->fh->print(${$upfiles[$idx]->{data}});
        $sfile->fh->close;
        my $mime_type = File::MimeInfo::Magic::magic($sfile->file_name);

        if (! $mime_type) {
          # if filename has the suffix "pdf", but isn't really a pdf, set mimetype for no suffix
          $mime_type = File::MimeInfo::Magic::mimetype($basefile);
          $mime_type = 'application/octet-stream' if $mime_type eq 'application/pdf' || !$mime_type;
        }
        if ( $self->file_type eq 'image' && $self->file_probe_image_type($mime_type, $basefile)) {
          next;
        }
        my ($existobj) = SL::File->get_all(object_id   => $self->object_id,
                                           object_type => $self->object_type,
                                           mime_type   => $mime_type,
                                           source      => $source,
                                           file_type   => $self->file_type,
                                           file_name   => $basefile,
                                      );

        if ($existobj) {
          push @existing, ($existobj->versions)[0]->file_version->guid.'_'.$sfile->file_name;
        } else {
          my $fileobj = SL::File->save(object_id        => $self->object_id,
                                       object_type      => $self->object_type,
                                       mime_type        => $mime_type,
                                       source           => $source,
                                       file_type        => $self->file_type,
                                       file_name        => $basefile,
                                       title            => $::form->{title},
                                       description      => $::form->{description},
                                       ## two possibilities: what is better ? content or sessionfile ??
                                       file_contents    => ${$upfiles[$idx]->{data}},
                                       file_path        => $sfile->file_name
                                     );
          unlink($sfile->file_name);
        }
        1;
      } or do {
        $self->js
          ->flash('error', t8('internal error (see details)'), $@)
          ->render;
        return;
      }
    }
  }
  $self->existing(\@existing);
  $self->_do_list(1);
}

sub action_download {
  my ($self) = @_;

  my $id      = $::form->{id};
  my $version = $::form->{version};

  my $file = SL::File->get(id => $id );
  $file->version($version) if $version;
  my $ref  = $file->get_content;
  if ( $file && $ref ) {
    return $self->send_file($ref,
      type => $file->mime_type,
      name => $file->file_name,
    );
  }
}

sub action_ajax_get_thumbnail {
  my ($self) = @_;

  my $id      = $::form->{file_id};
  my $version = $::form->{file_version};
  my $file    = SL::File->get(id => $id);

  $file->version($version) if $version;

  my $thumbnail = _create_thumbnail($file, $::form->{size});

  my $overlay_selector  = '#enlarged_thumb_' . $id;
  $overlay_selector    .= '_' . $version            if $version;
  $self->js
    ->attr($overlay_selector, 'src', 'data:' . $thumbnail->{thumbnail_img_content_type} . ';base64,' . MIME::Base64::encode_base64($thumbnail->{thumbnail_img_content}))
    ->data($overlay_selector, 'is-overlay-loaded', '1')
    ->render;
}


#
# filters
#

sub check_object_params {
  my ($self) = @_;

  my $id      = ($::form->{object_id} // 0) * 1;
  my $draftid = ($::form->{draft_id}  // 0) * 1;
  my $gldoc   = 0;
  my $type    = undef;

  if ( $draftid == 0 && $id == 0 && $::form->{is_global} ) {
    $gldoc = 1;
    $type  = $::form->{object_type};
  }
  elsif ( $id == 0 ) {
    $id   = $::form->{draft_id};
    $type = 'draft';
  } elsif ( $::form->{object_type} ) {
    $type = $::form->{object_type};
  }
  die "No object type"      unless $type;
  die "No file type"        unless $::form->{file_type};
  die "Unknown object type" unless $file_types{$type};

  $self->is_global($gldoc);
  $self->file_type($::form->{file_type});
  $self->object_type($type);
  $self->object_id($id);
  $self->object_model($file_types{$type}->{model});
  $self->object_right($file_types{$type}->{right});

 # $::auth->assert($self->object_right);

 # my $model = 'SL::DB::' . $self->object_model;
 # $self->object($model->new(id => $self->object_id)->load || die "Record not found");

  return 1;
}

#
# private methods
#

sub _delete_all {
  my ($self, $do_unimport, $infotext) = @_;
  my $files = '';
  my $ids = $::form->{ids};
  foreach my $version_guid (@{ $::form->{$ids} || [] }) {
    my $dbfile = SL::File->get(guid => $version_guid);
    if ($dbfile) {
      $files .= ' ' . $dbfile->file_name if $dbfile->delete_file_version;
    }
  }
  $self->js->flash('info', $infotext . $files) if $files;
  $self->_do_list(1);
}

sub _do_list {
  my ($self, $json) = @_;

  my @files;
  my @object_types = ($self->object_type);
  if ( $self->file_type eq 'document' ) {
    push @object_types, qw(dunning1 dunning2 dunning3 dunning_invoice dunning_orig_invoice) if $self->object_type eq 'invoice'; # hardcoded object types?
  }
  @files = SL::File->get_all_versions(object_id   => $self->object_id,
                                      object_type => \@object_types,
                                      file_type   => $self->file_type,
                                     );

  $self->files(\@files);

  $_->{thumbnail}     = _create_thumbnail($_)                     for @files;
  $_->{version_count} = SL::File->get_version_count(id => $_->id) for @files;

  if($self->object_type eq 'shop_image'){
    $self->js
      ->run('kivi.ShopPart.show_images', $self->object_id)
      ->render();
  }else{
    $self->_mk_render('file/list', 1, 0, $json);
  }
}

sub _get_from_import {
  my ($self, $path) = @_;
  my @foundfiles ;

  my $language = $::lx_office_conf{system}->{language};
  my $timezone = $::locale->get_local_time_zone()->name;
  if (opendir my $dir, $path) {
    my @files = (readdir $dir);
    foreach my $file ( @files) {
      next if (($file eq '.') || ($file eq '..'));
      $file = Encode::decode('utf-8', $file);

      next if ( -d "$path/$file" );

      my $tmppath = File::Spec->catfile( $path, $file );
      next if( ! -f $tmppath );

      my $st = stat($tmppath);
      my $dt = DateTime->from_epoch( epoch => $st->mtime, time_zone => $timezone, locale => $language );
      my $sname = $main::locale->quote_special_chars('HTML', $file);
      push @foundfiles, {
        'name'     => $file,
        'filename' => $sname,
        'path'     => $tmppath,
        'mtime'    => $st->mtime,
        'date'     => $dt->dmy('.') . " " . $dt->hms,
      };

    }
    closedir($dir);

  } else {
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_get_from_import opendir failed to open dir " . $path);
  }

  return @foundfiles;
}

sub _mk_render {
  my ($self, $template, $edit, $scanner, $json) = @_;
  my $err;
  eval {
    ##TODO make code configurable

    my $title;
    my @sources = $self->_get_sources();
    foreach my $source ( @sources ) {
      @{$source->{files}} = grep { $_->source eq $source->{name}} @{ $self->files };
    }
    if ( $self->file_type eq 'document' ) {
      $title = $main::locale->text('Documents');
    } elsif ( $self->file_type eq 'attachment' ) {
      $title = $main::locale->text('Attachments');
    } elsif ( $self->file_type eq 'image' ) {
      $title = $main::locale->text('Images');
    }

    my $output         = SL::Presenter->get->render(
      $template,
      title            => $title,
      SOURCES          => \@sources,
      edit_attachments => $edit,
      object_type      => $self->object_type,
      object_id        => $self->object_id,
      file_type        => $self->file_type,
      is_global        => $self->is_global,
      json             => $json,
    );
    if ( $json ) {
      $self->js->html('#'.$self->file_type.'_list_'.$self->object_type, $output);
      if ( $self->existing && scalar(@{$self->existing}) > 0) {
        my $first = shift @{$self->existing};
        my ($first_guid, $sfile) = split('_', $first, 2);
        my $file = SL::File->get(guid => $first_guid );
        $self->js->run('kivi.File.askForRename', $first_guid, $file->file_type, $file->file_name, $sfile, join (',', @{$self->existing}), $self->is_global);
      }
      $self->js->render();
    } else {
        $self->render(\$output, { layout => 0, process => 0 });
    }
    1;
  } or do {
    if ($json ){
      $self->js
        ->flash('error', t8('internal error (see details)'), $@)
        ->render;
    } else {
      $self->render('generic/error', { layout => 0 }, label_error => $@);
    }
  };
}


sub _get_sources {
  my ($self) = @_;
  my @sources;
  if ( $self->file_type eq 'document' ) {
    # TODO statt gen neue attribute in filetypes :
    if (($file_types{$self->object_type}->{gen}*1 & 4)==4) {
      # bit 3 is set => means upload
      my $source = {
        'name'         => 'uploaded',
        'title'        => $main::locale->text('uploaded Documents'),
        'chk_action'   => 'uploaded_documents_delete',
        'chk_title'    => $main::locale->text('Delete Documents'),
        'chkall_title' => $main::locale->text('Delete all'),
        'file_title'   => $main::locale->text('filename'),
        'confirm_text' => $main::locale->text('delete'),
        'can_rename'   => 1,
        'are_existing' => $self->existing ? 1 : 0,
        'rename_title' => $main::locale->text('Rename Attachments'),
        'can_upload'   => 1,
        'can_delete'   => 1,
        'upload_title' => $main::locale->text('Upload Documents'),
        'done_text'    => $main::locale->text('deleted')
      };
      push @sources , $source;
    }

    if (($file_types{$self->object_type}->{gen}*1 & 1)==1) {
      my $gendata = {
        'name'         => 'created',
        'title'        => $main::locale->text('generated Files'),
        'chk_action'   => 'documents_delete',
        'chk_title'    => $main::locale->text('Delete Documents'),
        'chkall_title' => $main::locale->text('Delete all'),
        'file_title'   => $main::locale->text('filename'),
        'confirm_text' => $main::locale->text('delete'),
        'can_delete'   => $::instance_conf->get_doc_delete_printfiles,
        'can_rename'   => $::instance_conf->get_doc_delete_printfiles,
        'rename_title' => $main::locale->text('Rename Documents'),
        'done_text'    => $main::locale->text('deleted')
      };
      push @sources , $gendata;
    }

    if (($file_types{$self->object_type}->{gen}*1 & 2)==2) {
      my @others =  SL::File->get_other_sources();
      foreach my $scanner_or_mailrx (@others) {
        my $other = {
          'name'         => $scanner_or_mailrx->{name},
          'title'        => $main::locale->text('from \'#1\' imported Files', $scanner_or_mailrx->{description}),
          'chk_action'   => $scanner_or_mailrx->{name}.'_unimport',
          'chk_title'    => $main::locale->text('Unimport documents'),
          'chkall_title' => $main::locale->text('Unimport all'),
          'file_title'   => $main::locale->text('filename'),
          'confirm_text' => $main::locale->text('unimport'),
          'can_rename'   => 1,
          'rename_title' => $main::locale->text('Rename Documents'),
          'can_import'   => 1,
          'can_delete'   => 0,
          'import_title' => $main::locale->text('Add Document from \'#1\'', $scanner_or_mailrx->{name}),
          'path'         => $scanner_or_mailrx->{directory},
          'done_text'    => $main::locale->text('unimported')
        };
        push @sources , $other;
      }
    }
  }
  elsif ( $self->file_type eq 'attachment' ) {
    my $attdata = {
      'name'         => 'uploaded',
      'title'        => $main::locale->text(''),
      'chk_action'   => 'attachments_delete',
      'chk_title'    => $main::locale->text('Delete Attachments'),
      'chkall_title' => $main::locale->text('Delete all'),
      'file_title'   => $main::locale->text('filename'),
      'confirm_text' => $main::locale->text('delete'),
      'can_rename'   => 1,
      'are_existing' => $self->existing ? 1 : 0,
      'rename_title' => $main::locale->text('Rename Attachments'),
      'can_upload'   => 1,
      'can_delete'   => 1,
      'upload_title' => $main::locale->text('Upload Attachments'),
      'done_text'    => $main::locale->text('deleted')
    };
    push @sources , $attdata;
  }
  elsif ( $self->file_type eq 'image' ) {
    my $attdata = {
      'name'         => 'uploaded',
      'title'        => $main::locale->text(''),
      'chk_action'   => 'images_delete',
      'chk_title'    => $main::locale->text('Delete Images'),
      'chkall_title' => $main::locale->text('Delete all'),
      'file_title'   => $main::locale->text('filename'),
      'confirm_text' => $main::locale->text('delete'),
      'can_rename'   => 1,
      'are_existing' => $self->existing ? 1 : 0,
      'rename_title' => $main::locale->text('Rename Images'),
      'can_upload'   => 1,
      'can_delete'   => 1,
      'upload_title' => $main::locale->text('Upload Images'),
      'done_text'    => $main::locale->text('deleted')
    };
    push @sources , $attdata;
  }
  return @sources;
}

# ignores all errors
# todo: cache thumbs?
sub _create_thumbnail {
  my ($file, $size) = @_;

  $size //= 64;

  my $filename;
  if (!eval { $filename = $file->get_file(); 1; }) {
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_create_thumbnail get_file failed: " . $EVAL_ERROR);
    return;
  }

  # Workaround for pfds which are not handled by file_probe_type.
  # Maybe use mime info stored in db?
  my $mime_type = File::MimeInfo::Magic::magic($filename);
  if ($mime_type =~ m{pdf}) {
    $filename = _convert_pdf_to_png($filename, size => $size);
  }
  return if !$filename;

  my $content;
  if (!eval { $content = slurp $filename; 1; }) {
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_create_thumbnail slurp failed: " . $EVAL_ERROR);
    return;
  }

  my $ret;
  if (!eval { $ret = file_probe_type($content, size => $size); 1; }) {
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_create_thumbnail file_probe_type failed: " . $EVAL_ERROR);
    return;
  }

  # file_probe_type returns a hash ref with thumbnail info and content
  # or an error message
  if ('HASH' ne ref $ret) {
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_create_thumbnail file_probe_type returned an error: " . $ret);
    return;
  }

  return $ret;
}

sub _convert_pdf_to_png {
  my ($filename, %params) = @_;

  my $size    = $params{size} // 64;
  my $sfile   = SL::SessionFile::Random->new();
  unless (-f $filename) {
    $::lxdebug->message(LXDebug::WARN(), "_convert_pdf_to_png failed, no file found: $filename");
    return;
  }
  # quotemeta for storno case "storno\ zu\ 1020" *nix only
  my $command = 'pdftoppm -singlefile -scale-to ' . $size . ' -png' . ' ' . quotemeta($filename) . ' ' . $sfile->file_name;

  if (system($command) == -1) {
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_convert_pdf_to_png: system call failed: " . $ERRNO);
    return;
  }
  if ($CHILD_ERROR) {
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_convert_pdf_to_png: pdftoppm failed with error code: " . ($CHILD_ERROR >> 8));
    $::lxdebug->message(LXDebug::WARN(), "SL::File::_convert_pdf_to_png: File: $filename");
    return;
  }

  return $sfile->file_name . '.png';
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Controller::File - Controller for managing files

=head1 SYNOPSIS

The Controller is called directly from the webpages

    <a href="controller.pl?action=File/list&file_type=document\
       &object_type=[% HTML.escape(type) %]&object_id=[% HTML.url(id) %]">


or indirectly via javascript functions from js/kivi.File.js

    kivi.popup_dialog({ url:     'controller.pl',
                        data:    { action     : 'File/ajax_upload',
                                   file_type  : 'uploaded',
                                   object_type: type,
                                   object_id  : id
                                 }
                           ...

=head1 DESCRIPTION

This is a controller for handling files in a storage independent way.
The storage may be a Filesystem,a WebDAV, a Database or DMS.
These backends must be configered in ClientConfig.
This Controller use as intermediate layer for storage C<SL::File>.

The Controller is responsible to display forms for displaying the files at the ERP-objects and
for uploading and downloading the files.

More description of the intermediate layer see L<SL::File>.

=head1 METHODS

=head2 C<action_list>

This loads a list of files on a webpage. This can be done with a normal submit or via an ajax/json call.
Dependent of file_type different sources are available.

For documents there are the 'created' source and the imports from scanners or email.
For attachments and images only the 'uploaded' source available.

Available C<FORM PARAMS>:

=over 4

=item C<form.object_id>

The Id of the ERP-object.

=item C<form.object_type>

The Type of the ERP-object like "sales_quotation". A clear mapping to the class/model exists in the controller.

=item C<form.file_type>

For one ERP-object may exists different type of documents the type may be "documents","attachments" or "images".
This file_type is a filter for the list.

=item C<form.json>

The method can be used as normal HTTP-Request (json=0) or as AJAX-JSON call to refresh the list if the parameter is set to 1.

=back


=head2 C<action_ajax_upload>


A new file or more files can selected by a dialog and insert into the system.


Available C<FORM PARAMS>:

=over 4

=item C<form.file_type>

This parameter describe here the source for a new file :
"attachments" and "images"

This is a normal upload selection, which may be more then one file to upload.

=item C<form.object_id>

and

=item C<form.object_type>

are the same as at C<action_list>

=back

=head2  C<action_ajax_files_uploaded>

The Upload of selected Files. The "multipart_formdata" is parsed in SL::Request into the formsvariable "form.ATTACHMENTS".
The filepaths are checked about Unix and Windows paths. Also the MIME type of the files are verified ( IS the contents of a *.pdf real PDF?).
If the same filename still exists at this object after the download for each existing filename a rename dialog will be opened.

If the filename is not changed the new uploaded file is a new version of the file, if the name is changed it is a new file.

Available C<FORM PARAMS>:

=over 4

=item C<form.ATTACHMENTS.uploadfiles>

This is an array of elements which have {filename} for the name and {data} for the contents.

Also object_id, object_type and file_type

=back

=head2 C<action_download>

This is the real download of a file normally called via javascript "$.download("controller.pl", data);"

Available C<FORM PARAMS>:

=over 4

Also object_id, object_type and file_type

=back

=head2 C<action_ajax_importdialog>

A Dialog with all available and not imported files to import is open.
More then one file can be selected.

Available C<FORM PARAMS>:

=over 4

=item C<form.source>

The name of the source like "scanner1" or "email"

=item C<form.path>

The full path to the directory on the server, where the files to import can found

Also object_id, object_type and file_type

=back

=head2 C<action_ajax_delete>

Some files can be deleted

Available C<FORM PARAMS>:

=over 4

=item C<form.ids>

The ids of the files to delete. Only this files are deleted not all versions of a file if the exists

=back

=head2 C<action_ajax_unimport>

Some files can be unimported, dependent of the source of the file. This means they are moved
back to the directory of the source

Available C<FORM PARAMS>:

=over 4

=item C<form.ids>

The ids of the files to unimport. Only these files are unimported not all versions of a file if the exists

=back

=head2 C<action_ajax_rename>

One file can be renamed. There can be some checks if the same filename still exists at one object.

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
