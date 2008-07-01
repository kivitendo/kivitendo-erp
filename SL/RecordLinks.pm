package RecordLinks;

use SL::Common;
use SL::DBUtils;

sub create_links {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(links));

  if (!scalar @{ $params{links} }) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $query    = qq|INSERT INTO record_links (from_table, from_id, to_table, to_id) VALUES (?, ?, ?, ?)|;
  my $sth      = prepare_query($form, $dbh, $query);

  foreach my $link (@{ $params{links} }) {
    next if ('HASH' ne ref $link);
    next if (!$link->{from_table} || !$link->{from_id} || !$link->{to_table} || !$link->{to_id});

    do_statement($form, $sth, $query, $link->{from_table}, conv_i($link->{from_id}), $link->{to_table}, conv_i($link->{to_id}));
  }

  $dbh->commit() unless ($params{dbh});

  $main::lxdebug->leave_sub();
}

sub get_links {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, [ qw(from_table from_id to_table to_id) ]);

  my $myconfig   = \%main::myconfig;
  my $form       = $main::form;

  my $dbh        = $params{dbh} || $form->get_standard_dbh($myconfig);

  my @conditions = ();
  my @values     = ();

  foreach my $col (qw(from_table from_id to_table to_id)) {
    next unless ($params{$col});

    if ('ARRAY' eq ref $params{$col}) {
      push @conditions, "$col IN (" . join(', ', ('?') x scalar(@{ $params{$col} })) . ")";
      push @values,     $col =~ m/table/ ? @{ $params{$col} } : map { conv_i($_) } @{ $params{$col} };

    } else {
      push @conditions, "$col = ?";
      push @values,     $col =~ m/table/ ? $params{$col} : conv_i($params{$col});
    }
  }

  my $query = qq|SELECT from_table, from_id, to_table, to_id
                 FROM record_links|;

  if (scalar @conditions) {
    $query .= qq| WHERE | . join(' AND ', map { "($_)" } @conditions);
  }

  my $links = selectall_hashref_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();

  return wantarray ? @{ $links } : $links;
}

1;
