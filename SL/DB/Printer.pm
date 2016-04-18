package SL::DB::Printer;

use strict;

use Carp;

use SL::DB::MetaSetup::Printer;
use SL::DB::Manager::Printer;
use SL::DB::Helper::Util;

__PACKAGE__->meta->initialize;

sub description {
  goto &printer_description;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')    if !$self->printer_description;
  push @errors, $::locale->text('The command is missing.')        if !$self->printer_command;
  push @errors, $::locale->text('The description is not unique.') if !SL::DB::Helper::Util::is_unique($self, 'printer_description');

  return @errors;
}

sub print_document {
  my ($self, %params) = @_;

  croak "Need either a 'content' or a 'file_name' parameter" if !defined($params{content}) && !$params{file_name};

  my $copies  = $params{copies} || 1;
  my $command = SL::Template::create(type => 'ShellCommand', form => Form->new(''))->parse($self->printer_command);
  my $content = $params{content} // scalar(File::Slurp::read_file($params{file_name}));

  for (1..$copies) {
    open my $out, '|-', $command or die $!;
    binmode $out;
    print $out $content;
    close $out;
  }
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Printer - Rose model for database table printers

=head1 SYNOPSIS

  my $printer = SL::DB::Printer->new(id => 4711)->load;
  $printer->print_document(
    copies    => 2,
    file_name => '/path/to/file.pdf',
  );

=head1 FUNCTIONS

=over 4

=item C<print_document %params>

Prints a document by spawning the external command stored in
C<$self-E<gt>printer_command> and sending content to it.

The caller must provide either the content to send to the printer
(parameter C<content>) or a name to a file whose content is sent
verbatim (parameter C<file_name>).

An optional parameter C<copies> can be given to specify the number of
copies to print. This is done by invoking the print command multiple
times. The number of copies defaults to 1.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
