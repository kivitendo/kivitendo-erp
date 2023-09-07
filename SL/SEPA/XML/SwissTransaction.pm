package SL::SEPA::XML::SwissTransaction;

use strict;

use parent qw(SL::SEPA::XML::Transaction);

use Carp;
use Encode;
use List::Util qw(first);
use POSIX qw(strftime);

sub _init {
  my $self       = shift;
  my %params     = @_;

  $self->{sepa}  = $params{sepa};
  delete $params{sepa};

  my $missing_parameter = first { !$params{$_} } qw(src_iban src_bic dst_iban company reference amount end_to_end_id);
  croak "Missing parameter: $missing_parameter" if ($missing_parameter);

  $params{end_to_end_id}  ||= 'NOTPROVIDED';
  $params{execution_date} ||= strftime "%Y-%m-%d", localtime;

  croak "Execution date format wrong for '$params{execution_date}': not YYYY-MM-DD." if ($params{execution_date} !~ /^\d{4}-\d{2}-\d{2}$/);

  map { $self->{$_} = $self->{sepa}->{iconv}->convert($params{$_})       } keys %params;
  map { $self->{$_} =~ s/\s+//g                                          } qw(src_iban src_bic dst_iban);
  map { $self->{$_} = $self->{sepa}->_replace_special_chars($self->{$_}) } qw(company reference end_to_end_id);
}

1;
