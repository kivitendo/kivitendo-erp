package SL::Helper::File;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(store_pdf append_general_pdf_attachments doc_storage_enabled);
our %EXPORT_TAGS = (all => \@EXPORT_OK,);
use SL::File;

sub doc_storage_enabled {
  return 0 unless $::instance_conf->get_doc_storage;
  return 1 if     $::instance_conf->get_doc_storage_for_documents eq 'Filesystem' && $::instance_conf->get_doc_files;
  return 1 if     $::instance_conf->get_doc_storage_for_documents eq 'Webdav'     && $::instance_conf->get_doc_webdav;
  return 0;
}

sub store_pdf {
  my ($self, $form) = @_;
  return unless $self->doc_storage_enabled;
  my $type = $form->{type};
  $type = $form->{formname}        if $form->{formname} && !$form->{type};
  $type = $form->{attachment_type} if $form->{attachment_type};
  my $id = $form->{id};
  $id = $form->{attachment_id} if $form->{attachment_id} && !$form->{id};
  return if !$id || !$type;
  my $prefix = $form->get_number_prefix_for_type();
  SL::File->save(
    object_id   => $id,
    object_type => $type,
    mime_type   => 'application/pdf',
    source      => 'created',
    file_type   => 'document',
    file_name   => $form->{attachment_filename},
    file_path   => $form->{tmpfile},
    file_number => $form->{"${prefix}number"},
  );
}

# This method also needed by $form to append all general pdf attachments
#
sub append_general_pdf_attachments {
  my ($self, %params) = @_;
  return 0 unless $::instance_conf->get_doc_storage;
  return 0 if !$params{filepath} || !$params{type};

  my @files = SL::File->get_all(
    object_id   => 0,
    object_type => $params{type},
    mime_type   => 'application/pdf'
  );
  return 0 if $#files < 0;

  my @pdf_file_names = ($params{filepath});
  foreach my $file (@files) {
    my $path = $file->get_file;
    push @pdf_file_names, $path if $path;
  }

  #TODO immer noch das alte Problem:
  #je nachdem von woher der Aufruf kommt ist man in ./users oder .
  my $savedir = POSIX::getcwd();
  chdir("$self->{cwd}");
  $self->merge_pdfs(
    file_names => \@pdf_file_names,
    out_path   => $params{filepath}
  );
  chdir("$savedir");

  return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::File - Helper for $::Form to store generated PDF-Documents

=head1 SYNOPSIS

# This Helper is used by SL::Form to store new generated PDF-Files and append general attachments to this documents.
#
# in SL::Form.pm:

 $self->store_pdf($self);

 $self->append_general_pdf_attachments(filepath => $pdf_filename, type => $form->{type}) if ( $ext_for_format eq 'pdf' );

#It is also used in MassPrint Helper
#

=head1 DESCRIPTION

The files with file_type "generated" are stored.

See also L<SL::File>.

=head1 METHODS


=head2 C<store_pdf>

Copy generated PDF-File to File destination.
This method is need from SL::Form after LaTeX-PDF Generation

=over 4

=item C<form.id>

ID of ERP-Document

=item C<form.type>

type of ERP-document

=item C<form.formname>

if no type is set this is used as type

=item C<form.attachment_id>

if no id is set this is used as id

=item C<form.tmpfile>

The path of the generated PDF-file

=item C<form.attachment_filename>

The generated filename which is used as new filename (without timestamp)

=back

=head2 C<append_general_pdf_attachments PARAMS>

This method also needed by SL::Form to append all general pdf attachments

needed C<PARAMS>:

=over 4

=item C<type>

type of ERP-document

=item C<outname>

Name of file to which the general attachments must be added

=back

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>


=cut
