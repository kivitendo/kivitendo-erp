package SL::Presenter::Part;

use strict;

use Exporter qw(import);
our @EXPORT = qw(part_picker);

sub part_picker {
  my ($self, $name, $value, %params) = @_;
  my $name_e    = $self->escape($name);

  my $ret =
    $self->input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => 'part_autocomplete', type => 'hidden') .
    $self->input_tag("", delete $params{type}, id => $self->name_to_id("$name_e\_type"), type => 'hidden') .
    $self->input_tag("", (ref $value && $value->can('description')) ? $value->description : '', id => $self->name_to_id("$name_e\_name"), %params) .
    $self->input_tag("", delete $params{column}, id => $self->name_to_id("$name_e\_column"), type => 'hidden');

  $self->html_tag('span', $ret, class => 'part_picker');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Presenter::Part - Part lelated presenter stuff

=head1 SYNOPSIS

see L<SL::Presenter>

=head1 DESCRIPTION

see L<SL::Presenter>

=head1 FUNCTIONS

=over 4

=item C<part_picker NAME, VALUE, PARAMS>

All-in-one picker widget for parts. The name will be both id and name of the
resulting hidden C<id> input field. An additional dummy input will be generated
which is used to find parts. For a detailed description of it's behaviour, see
section C<PART PICKER SPECIFICATION>.

C<VALUE> can be an id or C<Rose::DB:Object> instance.

If C<PARAMS> contains C<type> only parts of this type will be used for
autocompletion. Currently only one type may be specified.

Obsolete parts will by default not displayed for selection. However they are
accepted as default values and can persist during updates. As with other
selectors though, they are not selecatble once overridden.



=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
