# @tag: currencies
# @description: Erstellt neue Tabelle currencies. Währungen können dann einfacher eingegeben und unkritisch geändert werden.
# @depends: release_3_0_0 rm_whitespaces

package SL::DBUpgrade2::currencies;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);


sub run {
  my ($self) = @_;
  #Check wheather default currency exists
  my $query = qq|SELECT curr FROM defaults|;
  my ($currencies) = $self->dbh->selectrow_array($query);

  if (length($currencies) == 0 and length($main::form->{defaultcurrency}) == 0){
    print_no_default_currency();
    return 2;
  } else {
    if (!defined $::form->{defaultcurrency} || length($main::form->{defaultcurrency}) == 0){
      $main::form->{defaultcurrency} = (split m/:/, $currencies)[0];
    }
  }
  my @currency_array = grep {$_ ne '' } split m/:/, $currencies;

  $query = qq|SELECT DISTINCT curr FROM ar
              UNION
              SELECT DISTINCT curr FROM ap
              UNION
              SELECT DISTINCT curr FROM oe
              UNION
              SELECT DISTINCT curr FROM customer
              UNION
              SELECT DISTINCT curr FROM delivery_orders
              UNION
              SELECT DISTINCT curr FROM exchangerate
              UNION
              SELECT DISTINCT curr FROM vendor|;

  my $sth = $self->dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $main::form->{ORPHANED_CURRENCIES} = [];
  my $is_orphaned;
  my $rowcount = 0;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    next unless length($ref->{curr}) > 0;
    $is_orphaned = 1;
    foreach my $key (split(/:/, $currencies)) {
      if ($ref->{curr} eq $key) {
        $is_orphaned = 0;
        last;
      }
    }
    if ($is_orphaned) {
     push @{ $main::form->{ORPHANED_CURRENCIES} }, $ref;
     $main::form->{ORPHANED_CURRENCIES}[$rowcount]->{name} = "curr_$rowcount";
     $rowcount++;
    }
  }

  $sth->finish;

  if (scalar @{ $main::form->{ORPHANED_CURRENCIES} } > 0 and not ($main::form->{continue_options})) {
    print_orphaned_currencies();
    return 2;
  }

  if (defined $::form->{continue_options}) {
    if ($::form->{continue_options} eq 'break_up') {
      return 0;
    }

    if ($::form->{continue_options} eq 'insert') {
      for my $i (0..($rowcount-1)){
        push @currency_array, $main::form->{"curr_$i"};
      }
      create_and_fill_table($self, @currency_array);
      return 1;
    }

    my $still_orphaned;
    if ($::form->{continue_options} eq 'replace') {
      for my $i (0..($rowcount - 1)){
        $still_orphaned = 1;
        for my $item (@currency_array){
          if ($main::form->{"curr_$i"} eq $item){
            $still_orphaned = 0;
            $query = qq|DELETE FROM exchangerate WHERE curr = '| . $main::form->{"old_curr_$i"} . qq|'|;
            $self->db_query($query);
            $query = qq|UPDATE ap SET curr = '| . $main::form->{"curr_$i"} . qq|' WHERE curr = '| . $main::form->{"old_curr_$i"} . qq|'|;
            $self->db_query($query);
            $query = qq|UPDATE ar SET curr = '| . $main::form->{"curr_$i"} . qq|' WHERE curr = '| . $main::form->{"old_curr_$i"} . qq|'|;
            $self->db_query($query);
            $query = qq|UPDATE oe SET curr = '| . $main::form->{"curr_$i"} . qq|' WHERE curr = '| . $main::form->{"old_curr_$i"} . qq|'|;
            $self->db_query($query);
            $query = qq|UPDATE customer SET curr = '| . $main::form->{"curr_$i"} . qq|' WHERE curr = '| . $main::form->{"old_curr_$i"} . qq|'|;
            $self->db_query($query);
            $query = qq|UPDATE delivery_orders SET curr = '| . $main::form->{"curr_$i"} . qq|' WHERE curr = '| . $main::form->{"old_curr_$i"} . qq|'|;
            $self->db_query($query);
            $query = qq|UPDATE vendor SET curr = '| . $main::form->{"curr_$i"} . qq|' WHERE curr = '| . $main::form->{"old_curr_$i"} . qq|'|;
            $self->db_query($query);
            last;
          }
        }
        if ($still_orphaned){
          $main::form->{continue_options} = '';
          return do_update();
        }
      }
      create_and_fill_table($self, @currency_array);
      return 1;
    }
  }

  #No orphaned currencies, so create table:
  create_and_fill_table($self, @currency_array);
  return 1;
}; # end do_update

sub create_and_fill_table {
  my $self = shift;
  #Create an fill table currencies:
  my $query = qq|CREATE TABLE currencies (id   SERIAL        PRIMARY KEY,
                                          name TEXT NOT NULL UNIQUE)|;
  $self->db_query($query);
  foreach my $item ( @_ ) {
    $query = qq|INSERT INTO currencies (name) VALUES ('| . $item . qq|')|;
    $self->db_query($query);
  }

  #Set default currency if no currency was chosen:
  $query = qq|UPDATE ap SET curr = '| . $main::form->{"defaultcurrency"} . qq|' WHERE curr IS NULL or curr='';|;
  $query .= qq|UPDATE ar SET curr = '| . $main::form->{"defaultcurrency"} . qq|' WHERE curr IS NULL or curr='';|;
  $query .= qq|UPDATE oe SET curr = '| . $main::form->{"defaultcurrency"} . qq|' WHERE curr IS NULL or curr='';|;
  $query .= qq|UPDATE customer SET curr = '| . $main::form->{"defaultcurrency"} . qq|' WHERE curr IS NULL or curr='';|;
  $query .= qq|UPDATE delivery_orders SET curr = '| . $main::form->{"defaultcurrency"} . qq|' WHERE curr IS NULL or curr='';|;
  $query .= qq|UPDATE vendor SET curr = '| . $main::form->{"defaultcurrency"} . qq|' WHERE curr IS NULL or curr='';|;
  $query .= qq|DELETE FROM exchangerate WHERE curr IS NULL or curr='';|;
  $self->db_query($query);

  #Check wheather defaultcurrency is already in table currencies:
  $query = qq|SELECT name FROM currencies WHERE name = '| . $main::form->{defaultcurrency} . qq|'|;
  my ($insert_default) = $self->dbh->selectrow_array($query);

  if (!$insert_default) {
    $query = qq|INSERT INTO currencies (name) VALUES ('| . $main::form->{defaultcurrency} . qq|')|;
    $self->db_query($query);
  }

  #Create a new columns currency_id and update with curr.id:
  $query = qq|ALTER TABLE ap ADD currency_id INTEGER;
              ALTER TABLE ar ADD currency_id INTEGER;
              ALTER TABLE oe ADD currency_id INTEGER;
              ALTER TABLE customer ADD currency_id INTEGER;
              ALTER TABLE delivery_orders ADD currency_id INTEGER;
              ALTER TABLE exchangerate ADD currency_id INTEGER;
              ALTER TABLE vendor ADD currency_id INTEGER;
              ALTER TABLE defaults ADD currency_id INTEGER;|;
  $self->db_query($query);
  #Set defaultcurrency:
  $query = qq|UPDATE defaults SET currency_id= (SELECT id FROM currencies WHERE name = '| . $main::form->{defaultcurrency} . qq|')|;
  $self->db_query($query);
  $query = qq|UPDATE ap SET currency_id = (SELECT id FROM currencies c WHERE c.name = ap.curr);
              UPDATE ar SET currency_id = (SELECT id FROM currencies c WHERE c.name = ar.curr);
              UPDATE oe SET currency_id = (SELECT id FROM currencies c WHERE c.name = oe.curr);
              UPDATE customer SET currency_id = (SELECT id FROM currencies c WHERE c.name = customer.curr);
              UPDATE delivery_orders SET currency_id = (SELECT id FROM currencies c WHERE c.name = delivery_orders.curr);
              UPDATE exchangerate SET currency_id = (SELECT id FROM currencies c WHERE c.name = exchangerate.curr);
              UPDATE vendor SET currency_id = (SELECT id FROM currencies c WHERE c.name = vendor.curr);|;
  $self->db_query($query);

  #Drop column 'curr':
  $query = qq|ALTER TABLE ap DROP COLUMN curr;
              ALTER TABLE ar DROP COLUMN curr;
              ALTER TABLE oe DROP COLUMN curr;
              ALTER TABLE customer DROP COLUMN curr;
              ALTER TABLE delivery_orders DROP COLUMN curr;
              ALTER TABLE exchangerate DROP COLUMN curr;
              ALTER TABLE vendor DROP COLUMN curr;
              ALTER TABLE defaults DROP COLUMN curr;|;
  $self->db_query($query);

  #Set NOT NULL constraints:
  $query = qq|ALTER TABLE ap ALTER COLUMN currency_id SET NOT NULL;
              ALTER TABLE ar ALTER COLUMN currency_id SET NOT NULL;
              ALTER TABLE oe ALTER COLUMN currency_id SET NOT NULL;
              ALTER TABLE customer ALTER COLUMN currency_id SET NOT NULL;
              ALTER TABLE delivery_orders ALTER COLUMN currency_id SET NOT NULL;
              ALTER TABLE exchangerate ALTER COLUMN currency_id SET NOT NULL;
              ALTER TABLE vendor ALTER COLUMN currency_id SET NOT NULL;
              ALTER TABLE defaults ALTER COLUMN currency_id SET NOT NULL;|;
  $self->db_query($query);

  #Set foreign keys:
  $query = qq|ALTER TABLE ap ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);
              ALTER TABLE ar ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);
              ALTER TABLE oe ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);
              ALTER TABLE customer ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);
              ALTER TABLE delivery_orders ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);
              ALTER TABLE exchangerate ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);
              ALTER TABLE vendor ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);
              ALTER TABLE defaults ADD FOREIGN KEY (currency_id) REFERENCES currencies(id);|;
  $self->db_query($query);

};

sub print_no_default_currency {
  print $main::form->parse_html_template("dbupgrade/no_default_currency");
};

sub print_orphaned_currencies {
  print $main::form->parse_html_template("dbupgrade/orphaned_currencies");
};

1;
