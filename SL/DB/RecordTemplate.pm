package SL::DB::RecordTemplate;

use strict;

use DateTime::Format::Strptime;
use List::Util qw(first);

use SL::DB::MetaSetup::RecordTemplate;
use SL::DB::Manager::RecordTemplate;

__PACKAGE__->meta->add_relationship(
  record_template_items => {
    type       => 'one to many',
    class      => 'SL::DB::RecordTemplateItem',
    column_map => { id => 'record_template_id' },
  },
);

__PACKAGE__->meta->initialize;

sub items { goto &record_template_items; }

sub _replace_variables {
  my ($self, %params) = @_;

  foreach my $sub (@{ $params{fields} }) {
    my $value = $params{object}->$sub;
    next if ($value // '') eq '';

    $value =~ s{ <\% ([a-z0-9_]+) ( \s+ format \s*=\s* (.*?) \s* )? \%> }{
      my ($key, $format) = ($1, $3);
      my $new_value;

      if (!$params{variables}->{$key}) {
        $new_value = '';

      } elsif ($format) {
        $new_value = DateTime::Format::Strptime->new(
          pattern     => $format,
          locale      => 'de_DE',
          time_zone   => 'local',
        )->format_datetime($params{variables}->{$key}->[0]);

      } else {
        $new_value = $params{variables}->{$1}->[1]->($params{variables}->{$1}->[0]);
      }

      $new_value;

    }eigx;

    $params{object}->$sub($value);
  }
}

sub _generate_variables {
  my ($self, $reference_date) = @_;

  $reference_date           //= DateTime->today_local;
  my @month_names             = (
    $::locale->text('January'), $::locale->text('February'), $::locale->text('March'),     $::locale->text('April'),   $::locale->text('May'),      $::locale->text('June'),
    $::locale->text('July'),    $::locale->text('August'),   $::locale->text('September'), $::locale->text('October'), $::locale->text('November'), $::locale->text('December'),
  );

  my $variables = {
    current_quarter     => [ $reference_date->clone->truncate(to => 'month'),                        sub { $_[0]->quarter } ],
    previous_quarter    => [ $reference_date->clone->truncate(to => 'month')->subtract(months => 3), sub { $_[0]->quarter } ],
    next_quarter        => [ $reference_date->clone->truncate(to => 'month')->add(     months => 3), sub { $_[0]->quarter } ],

    current_month       => [ $reference_date->clone->truncate(to => 'month'),                        sub { $_[0]->month } ],
    previous_month      => [ $reference_date->clone->truncate(to => 'month')->subtract(months => 1), sub { $_[0]->month } ],
    next_month          => [ $reference_date->clone->truncate(to => 'month')->add(     months => 1), sub { $_[0]->month } ],

    current_month_long  => [ $reference_date->clone->truncate(to => 'month'),                        sub { $month_names[ $_[0]->month - 1 ] } ],
    previous_month_long => [ $reference_date->clone->truncate(to => 'month')->subtract(months => 1), sub { $month_names[ $_[0]->month - 1 ] } ],
    next_month_long     => [ $reference_date->clone->truncate(to => 'month')->add(     months => 1), sub { $month_names[ $_[0]->month - 1 ] } ],

    current_year        => [ $reference_date->clone->truncate(to => 'year'),                         sub { $_[0]->year } ],
    previous_year       => [ $reference_date->clone->truncate(to => 'year')->subtract(years => 1),   sub { $_[0]->year } ],
    next_year           => [ $reference_date->clone->truncate(to => 'year')->add(     years => 1),   sub { $_[0]->year } ],

    reference_date      => [ $reference_date->clone,                                                 sub { $::locale->format_date(\%::myconfig, $_[0]) } ],
  };

  return $variables;
}

sub _text_column_names {
  my ($self, $object) = @_;
  return map { $_->name } grep { ref($_) =~ m{::Text} } @{ $object->meta->columns };
}

sub substitute_variables {
  my ($self, $reference_date) = @_;

  my $variables    = $self->_generate_variables($reference_date);
  my @text_columns = $self->_text_column_names($self);

  $self->_replace_variables(
    object    => $self,
    variables => $variables,
    fields    => \@text_columns,
  );

  @text_columns = $self->_text_column_names(SL::DB::RecordTemplateItem->new);

  foreach my $item (@{ $self->items }) {
    $self->_replace_variables(
      object    => $item,
      variables => $variables,
      fields    => \@text_columns,
    );
  }
}

sub template_name_to_use {
  my ($self, @names) = @_;

  return first { ($_ // '') ne '' } (@names, $self->template_name, $::locale->text('unnamed record template'));
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::RecordTemplate — Templates for accounts receivable
transactions, accounts payable transactions and generic ledger
transactiona

=head1 FUNCTIONS

=over 4

=item C<items>

An alias for C<record_template_items>.

=item C<substitute_variables> C<[$reference_date]>

Texts in record templates can contain placeholders. This function
replaces those placeholders by their actual value. Placeholders use
the syntax C<E<lt>%variableE<gt>> or C<E<lt>%variable format=…E<gt>>
for a custom format (see L<DateTime::Format::Strptime> for available
formatting characters).

The variables are calculated based on C<$reference_date> which must be
an instance of L<DateTime> if given. If left out, it defaults to the
current day.

Supported variables are:

=over 2

=item * C<current_quarter>, C<previous_quarter>, C<next_quarter> — the
quarter as a number between 1 and 4 inclusively

=item * C<current_month>, C<previous_month>, C<next_month> — the
month as a number between 1 and 12 inclusively

=item * C<current_month_long>, C<previous_month_long>,
C<next_month_long> — the month's name (e.g. C<August>).

=item * C<current_year>, C<previous_year>, C<next_year> — the
year (e.g. C<2017>)

=item * C<reference_date> — the reference date in the user's date style
(e.g. C<27.11.2017>)

=back

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
