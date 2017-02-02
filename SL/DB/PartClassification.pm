
package SL::DB::PartClassification;

use strict;

use SL::DB::MetaSetup::PartClassification;
use SL::DB::Manager::PartClassification;

__PACKAGE__->meta->initialize;
__PACKAGE__->before_delete('can_be_deleted');

# check if the description and abbreviation is present
#
sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')  if !$self->description;
  push @errors, $::locale->text('The abbreviation is missing.') if !$self->abbreviation;

  return @errors;
}

sub can_be_deleted {
  my ($self) = @_;

  # The first five part classifications must not be deleted.
  return defined($self->id) && ($self->id >= 5);
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::PartClassification

=head1 SYNOPSIS

Additional to the article types "part", "assembly", "service" and "assortement"
the parts classification specifies other ortogonal attributes

=head1 DESCRIPTION

The primary attributes are the rule
of the article as "used_for_sales" or "used_for_purchase".

Another attribute is "report_separate". This attribute may be used for some additional costs like
transport, packaging. These article are reported separate in the list of an invoice if
the print template is using the variables <%separate_XXX_subtotal%>  and XXX is the shortcut of the parts classification.
The variables <%non_separate_subtotal%> has the sum of all other parts of an invoice.
(See also LaTeX Documentation).

Additional other attributes may follow

To see this attributes in a short way there are shortcuts of one (or two characters, if needed for compare )
which may be translated in the specified language

The type of the article is also as shortcut available, so this combined type and classification shortcut
is used short as "Type"

English type shortcuts are 'P','A','S'
German  type shortcuts are 'W','E','D'
The can set in the language-files

To get the localized abbreviations you can use L<SL::Presenter::Part> .

=head1 METHODS

=head2 validate

 $self->validate();

check if the description and abbreviation is present


=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>


=cut
