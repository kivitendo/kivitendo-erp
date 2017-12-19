package SL::Layout::Content;

use strict;
use parent qw(SL::Layout::Base);

sub start_content {
  "<div id='content'>";
}

sub end_content {
  "</div>";
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::Content

=head1 DESCRIPTION

Pseudo layout for the position of the actual content in the layout. Currently
only implements the start_content/end_content blocks used for styling.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
