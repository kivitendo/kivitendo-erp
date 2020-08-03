package SL::Helper::MassPrintCreatePDF;

use strict;

use SL::Webdav;

use Exporter 'import';
our @EXPORT_OK = qw(create_massprint_pdf merge_massprint_pdf create_pdfs print_pdfs);
our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);

sub create_pdfs {
  my ($self, %params) = @_;
  my @pdf_file_names;
  foreach my $document (@{ $params{documents} }) {
    $params{document} = $document;
    push @pdf_file_names, $self->create_massprint_pdf(%params);
  }

  return @pdf_file_names;
}

sub create_massprint_pdf {
  my ($self, %params) = @_;
  my $form = Form->new('');
  my %create_params = (
    variables => $form,
    record    => $params{document},
    return    => 'file_name',
  );
  ## find_template may return a list !
  $create_params{template} = $self->find_template(name => $params{variables}->{formname}, printer_id => $params{printer_id});
  $form->{cwd}= POSIX::getcwd();

  $form->{$_} = $params{variables}->{$_} for keys %{ $params{variables} };

  $create_params{variable_content_types} = $form->get_variable_content_types();
  $params{document}->flatten_to_form($form, format_amounts => 1);
  # flatten_to_form sets payment_terms from customer/vendor - we do not want that here
  # really ??
  delete $form->{payment_terms} if !$form->{payment_id};
  for my $i (1 .. $form->{rowcount}) {
    $form->{"sellprice_$i"} = $form->{"fxsellprice_$i"};
  }

  $form->prepare_for_printing;

  $form->{language}            = '_' . $form->{language};
  $form->{attachment_filename} = $form->generate_attachment_filename;

  my $pdf_filename = $self->create_pdf(%create_params);

  if ($::instance_conf->get_webdav_documents && !$form->{preview}) {
    my $webdav = SL::Webdav->new(
      type     => $params{document}->type,
      number   => $params{document}->record_number,
    );
    my $webdav_file = SL::Webdav::File->new(
      webdav   => $webdav,
      filename => $form->{attachment_filename},
    );
    eval {
      $webdav_file->store(file => $pdf_filename);
      1;
    } or do {
      push @{ $params{errors} }, $@ if exists $params{errors};
    }
  }

  if ( $::instance_conf->get_doc_storage && ! $form->{preview}) {
    $self->append_general_pdf_attachments(filepath => $pdf_filename, type => $form->{type} );
    $form->{tmpfile} = $pdf_filename;
    $form->{id}      = $params{document}->id;
    $self->store_pdf($form);
  }
  $form->{id} = $params{document}->id;
  if ( ! $form->{preview} ) {
    if ( ref($params{document}) eq 'SL::DB::DeliveryOrder' ) {
      $form->{snumbers} = "ordnumber_" . $params{document}->donumber;
    }
    else {
      $form->{snumbers} = "unknown";
    }
    $form->{addition} = "PRINTED";
    $form->{what_done} = $::form->{type};
    $form->save_history;
  }
  return $pdf_filename;
}

sub merge_massprint_pdf {
  my ($self, %params)     = @_;
  return unless $params{file_names} && $params{type};

  my $job_obj = $self->{job_obj};
  my $data    = $job_obj->data_as_hash;
  my @pdf_file_names = @{$params{file_names}};

  eval {
    my $file_name = 'mass_'.$params{type}.'_'.$job_obj->id . '.pdf';
    my $sfile     = SL::SessionFile->new($file_name, mode => 'w', session_id => $data->{session_id});
    $sfile->fh->close;
    $data->{pdf_file_name} = $sfile->file_name;

    $self->merge_pdfs(file_names => \@pdf_file_names, bothsided => $data->{bothsided}, out_path => $data->{pdf_file_name});
    unlink @pdf_file_names;

    1;

  } or do {
    push @{ $data->{print_errors} }, { message => $@ };
  };

  $job_obj->update_attributes(data_as_hash => $data);
}

sub print_pdfs {
  my ($self)     = @_;

  my $job_obj         = $self->{job_obj};
  my $data            = $job_obj->data_as_hash;
  my $printer_id      = $data->{printer_id};
  my $copy_printer_id = $data->{copy_printer_id};

  return if !$printer_id;

  my $out;

  foreach  my $local_printer_id ($printer_id, $copy_printer_id) {
    next unless $local_printer_id;
    SL::DB::Printer
      ->new(id => $local_printer_id)
      ->load
      ->print_document(file_name => $data->{pdf_file_name});
  }

}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::MassPrint_CreatePDF


=head1 DESCRIPTION

This Helper used bei Background Processing for Mass Printing.
The redundant way to fill data for createPDF is concentrated into this helper.
There are some additional settings for printing which are missed in CreatePDF Helper
and also the appending of generic PDF-Documents.

(This extension may be included in the CreatePDF Helper).


=head1 REQUIRES

L<SL::Helper::CreatePDF>

=head1 METHODS

=head2 C<create_massprint_pdf PARAMS>

a tempory $form is used to set

=over 2

=item 1. content types

=item 2. flatten_to_form

=item 3. prepare_for_printing

=item 4. set history

=back

before printing is done

Recognized parameters are (not a complete list):

=over 2

=item * C<errors> – optional. If given, it must be an array ref. This will be
filled with potential errors.

=back


=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>


=cut
