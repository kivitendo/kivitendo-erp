package RecordLinks;

use utf8;
use strict;

use SL::Common;
use SL::DBUtils;
use Data::Dumper;
use List::Util qw(reduce);
use SL::DB;

sub create_links {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  if ($params{mode} && ($params{mode} eq 'ids')) {
    Common::check_params_x(\%params, [ qw(from_ids to_ids) ]);

  } else {
    Common::check_params(\%params, qw(links));

  }

  my @links;

  if ($params{mode} && ($params{mode} eq 'ids')) {
    my ($from_to, $to_from) = $params{from_ids} ? qw(from to) : qw(to from);
    my %ids;

    if ('ARRAY' eq ref $params{"${from_to}_ids"}) {
      $ids{$from_to} = $params{"${from_to}_ids"};
    } else {
      $ids{$from_to} = [ grep { $_ } map { $_ * 1 } split m/\s+/, $params{"${from_to}_ids"} ];
    }

    if (my $num = scalar @{ $ids{$from_to} }) {
      $ids{$to_from} = [ ($params{"${to_from}_id"}) x $num ];
      @links         = map { { 'from_table' => $params{from_table},
                               'from_id'    => $ids{from}->[$_],
                               'to_table'   => $params{to_table},
                               'to_id'      => $ids{to}->[$_],      } } (0 .. $num - 1);
    }

  } else {
    @links = @{ $params{links} };
  }

  if (!scalar @links) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = $params{dbh} || SL::DB->client->dbh;

    my $query    = qq|INSERT INTO record_links (from_table, from_id, to_table, to_id) VALUES (?, ?, ?, ?)|;
    my $sth      = prepare_query($form, $dbh, $query);

    foreach my $link (@links) {
      next if ('HASH' ne ref $link);
      next if (!$link->{from_table} || !$link->{from_id} || !$link->{to_table} || !$link->{to_id});

      do_statement($form, $sth, $query, $link->{from_table}, conv_i($link->{from_id}), $link->{to_table}, conv_i($link->{to_id}));
    }

    1;
  }) or do { die SL::DB->client->error };

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

sub get_links_via {
  $main::lxdebug->enter_sub();

  use SL::MoreCommon;
  use Data::Dumper;

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, [ qw(from_table from_id to_table to_id) ]);
  Common::check_params(\%params, "via");

  my @hops = ref $params{via} eq 'ARRAY'
           ? @{ $params{via} }
           :    $params{via};
  unshift @hops, +{ table => $params{from_table}, id => $params{from_id} };
  push    @hops, +{ table => $params{to_table},   id => $params{to_id} };

  my $myconfig   = \%main::myconfig;
  my $form       = $main::form;

  my $last_hop   = shift @hops;
  my @links;
  for my $hop (@hops) {

    my @temp_links = $self->get_links(
      from_table => $last_hop->{table},
      from_id    => $last_hop->{id},
      to_table   => $hop->{table},
      to_id      => $hop->{id},
    );

    # short circuit if any of these are empty
    return wantarray ? () : [] unless scalar @temp_links;

    push @links, \@temp_links;
    $last_hop  =  $hop;
  }

  my $result = reduce {
    [
      grep { $_ }
      cross {
        if (   $a->{to_table} eq $b->{from_table}
            && $a->{to_id}    eq $b->{from_id} ) {
          +{ from_table => $a->{from_table},
             from_id    => $a->{from_id},
             to_table   => $b->{to_table},
             to_id      => $b->{to_id} }
          }
        } @{ $a }, @{ $b }
    ]
  } @links;

  $main::lxdebug->leave_sub();

  return wantarray ? @{ $result } : $result;
}

sub delete {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, [ qw(from_table from_id to_table to_id) ]);

  my $myconfig   = \%main::myconfig;
  my $form       = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh        = $params{dbh} || SL::DB->client->dbh;

    # content
    my (@where_tokens, @where_values);

    for my $col (qw(from_table from_id to_table to_id)) {
      add_token(\@where_tokens, \@where_values, col => $col, val => $params{$col}) if $params{$col};
    }

    my $where = @where_tokens ? "WHERE ". join ' AND ', map { "($_)" } @where_tokens : '';
    my $query = "DELETE FROM record_links $where";

    do_query($form, $dbh, $query, @where_values);

    1;
  }) or die { SL::DD->client->error };

  $main::lxdebug->leave_sub();
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::RecordLinks - Verlinkung von kivitendo Objekten.

=head1 SYNOPSIS

  use SL::RecordLinks;

  my @links = RecordLinks->get_links(
    from_table => 'ar',
    from_id    => 2,
    to_table   => 'oe',
  );
  my @links = RecordLinks->get_links_via(
    from_table => 'oe',
    to_id      => '14',
    via        => [
      { id => 12 },
      { id => 13},
    ],
  );

  RecordLinks->create_links(
    mode       => 'ids',
    from_table => 'ar',
    from_id    => 1,
    to_table   => 'oe',
    to_ids     => [4, 6, 9],
  )
  RecordLinks->create_links(@links);

  delete

=head1 DESCRIPTION

Transitive RecordLinks mit get_links_via.

get_links_via erwartet den zusätzlichen parameter via. via ist ein
hashref mit den jeweils optionalen Einträgen table und id, die sich
genauso verhalten wie die from/to_table/id werte der get_links funktion.

Alternativ kann via auch ein Array dieser Hashes sein:

  get_links_via(
    from_table => 'oe',
    from_id    => 1,
    to_table   => 'ar',
    via        => {
      table      => 'delivery_orders'
    },
  )

  get_links_via(
    from_table => 'oe',
    to_id      => '14',
    via        => [
      { id => 12 },
      { id => 13},
    ],
  )

Die Einträge in einem via-Array werden exakt in dieser Reihenfolge
benutzt und sind nicht optional. Da obige Beispiel würde also die
Verknüpfung:

  oe:11 -> ar:12 -> is:13 -> do:14

finden, nicht aber:

  oe:11 -> ar:13 -> do:14

=cut
