package SL::SEPA::XML::Transaction;

use strict;

use Carp;
use Encode;
use List::Util qw(first);
use POSIX qw(strftime);

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  $self->_init(@_);

  return $self;
}

sub _init {
  my $self       = shift;
  my %params     = @_;

  $self->{sepa}  = $params{sepa};
  delete $params{sepa};

  my $missing_parameter = first { !$params{$_} } qw(src_iban src_bic dst_iban dst_bic company reference amount end_to_end_id);
  croak "Missing parameter: $missing_parameter" if ($missing_parameter);

  $params{end_to_end_id}  ||= 'NOTPROVIDED';
  $params{execution_date} ||= strftime "%Y-%m-%d", localtime;

  croak "Execution date format wrong for '$params{execution_date}': not YYYY-MM-DD." if ($params{execution_date} !~ /^\d{4}-\d{2}-\d{2}$/);

  map { $self->{$_} = $self->{sepa}->{iconv}->convert($params{$_})       } keys %params;
  map { $self->{$_} =~ s/\s+//g                                          } qw(src_iban src_bic dst_iban dst_bic);
  map { $self->{$_} = $self->{sepa}->_replace_special_chars($self->{$_}) } qw(company reference end_to_end_id);
}

sub get {
  my $self    = shift;
  my $key     = shift;
  my $max_len = shift;

  return undef if (!defined $self->{$key});

  my $str = $max_len ? substr($self->{$key}, 0, $max_len) : $self->{$key};

  return encode('UTF-8', $str);
}

1;
