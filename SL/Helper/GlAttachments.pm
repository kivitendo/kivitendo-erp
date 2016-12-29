#
# Helper for General Ledger Reports
#
# 1. Fetch the Count of PDF-Documents of one item of a General Ledger Report
# 2. Append the contents of all items of a General Ledger Report

package SL::Helper::GlAttachments;

use strict;

use Exporter 'import';
our @EXPORT_OK = qw(count_gl_attachments append_gl_pdf_attachments);
our %EXPORT_TAGS = (
  all => \@EXPORT_OK,
);
use SL::File;

my %gl_types = (
  'ar' => 'invoice',
  'ap' => 'purchase_invoice',
  'gl' => 'gl_transaction',
);

#
# Fetch the Count of PDF-Documents with are related to the $id parameter
# The parameter $gltype may be 'ar','ap' or 'gl'.
#
sub count_gl_pdf_attachments {
  my ($self,$id,$gltype) = @_;
  return SL::File->get_all_count(object_id   => $id,
                                 object_type => $gl_types{$gltype},
                                 mime_type   => 'application/pdf',
                                 );
}

# Append the contents of all PDF-Documents to the base $content
# This Method is only used in SL/Reportgenerator.pm if the $form->{GD} array is set.
# The elements of the array need the two elements $ref->{type},$ref->{id}
#
sub append_gl_pdf_attachments {
  my ($self,$form,$content) = @_;
  my @filelist;
  foreach my $ref (@{ $form->{GL} }) {
    my @files = SL::File->get_all(object_id   => $ref->{id},
                                  object_type => $gl_types{$ref->{type}},
                                  mime_type   => 'application/pdf',
                                 );
    push @filelist, $_->get_file for @files;
  }
  return $self->merge_pdfs(file_names => \@filelist , inp_content => $content );
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::GlAttachments - Helper for General Ledger Reports

=head1 SYNOPSIS

   $self->count_gl_pdf_attachments($ref->{id},$ref->{type});
   $self->append_gl_pdf_attachments($form,$base_content);


=head1 DESCRIPTION

Helper for General Ledger Reports

1. Fetch the Count of PDF-Documents of one item of a General Ledger Report

2. Append the contents of all items of a General Ledger Report


=head1 METHODS

=head2 C<count_gl_pdf_attachments>

count_gl_pdf_attachments($id,$type);

Fetch the Count of PDF-Documents with are related to the $id parameter
The parameter $type may be 'ar','ap' or 'gl'.

=head2 C<append_gl_pdf_attachments>

append_gl_pdf_attachments($form,$content);

Append the contents of all PDF-Documents to the base $content
This Method is only used in SL/Reportgenerator.pm if the $form->{GD} array is set.
The elements of the array need the two elements $ref->{type},$ref->{id}

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>


=cut

