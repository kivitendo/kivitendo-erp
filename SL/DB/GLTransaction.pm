package SL::DB::GLTransaction;

use strict;

use SL::DB::MetaSetup::GLTransaction;
use SL::Locale::String qw(t8);
use List::Util qw(sum);
use SL::DATEV;
use Carp;
use Data::Dumper;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->add_relationship(
  transactions   => {
    type         => 'one to many',
    class        => 'SL::DB::AccTransaction',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'chart' ],
      sort_by      => 'acc_trans_id ASC',
    },
  },
);

__PACKAGE__->meta->initialize;

sub abbreviation {
  my $self = shift;

  my $abbreviation = $::locale->text('GL Transaction (abbreviation)');
  $abbreviation   .= "(" . $::locale->text('Storno (one letter abbreviation)') . ")" if $self->storno;
  return $abbreviation;
}

sub displayable_type {
  return t8('GL Transaction');
}

sub oneline_summary {
  my ($self) = @_;
  my $amount =  sum map { $_->amount if $_->amount > 0 } @{$self->transactions};
  $amount = $::form->format_amount(\%::myconfig, $amount, 2);
  return sprintf("%s: %s %s %s (%s)", $self->abbreviation, $self->description, $self->reference, $amount, $self->transdate->to_kivitendo);
}

sub link {
  my ($self) = @_;

  my $html;
  $html   = $self->presenter->gl_transaction(display => 'inline');

  return $html;
}

sub invnumber {
  return $_[0]->reference;
}

sub date { goto &gldate }

sub post {
  my ($self) = @_;

  my @errors = $self->validate;
  croak t8("Errors in GL transaction:") . "\n" . join("\n", @errors) . "\n" if scalar @errors;

  # make sure all the defaults are set:
  require SL::DB::Employee;
  my $employee_id = SL::DB::Manager::Employee->current->id;
  $self->type(undef);
  $self->employee_id($employee_id) unless defined $self->employee_id || defined $self->employee;
  $self->ob_transaction('f') unless defined $self->ob_transaction;
  $self->cb_transaction('f') unless defined $self->cb_transaction;
  $self->gldate(DateTime->today_local) unless defined $self->gldate; # should user even be allowed to set this manually?
  $self->transdate(DateTime->today_local) unless defined $self->transdate;

  $self->db->with_transaction(sub {
    $self->save;

    if ($::instance_conf->get_datev_check_on_gl_transaction) {
      my $datev = SL::DATEV->new(
        dbh      => $self->dbh,
        trans_id => $self->id,
      );

      $datev->generate_datev_data;

      if ($datev->errors) {
         die join "\n", t8('DATEV check returned errors:'), $datev->errors;
      }
    }

    require SL::DB::History;
    SL::DB::History->new(
      trans_id    => $self->id,
      snumbers    => 'gltransaction_' . $self->id,
      employee_id => $employee_id,
      addition    => 'POSTED',
      what_done   => 'gl transaction',
    )->save;

    1;
  }) or die t8("Error when saving: #1", $self->db->error);

  return $self;
}

sub add_chart_booking {
  my ($self, %params) = @_;

  require SL::DB::Chart;
  die "add_chart_booking needs a transdate" unless $self->transdate;
  die "add_chart_booking needs taxincluded" unless defined $self->taxincluded;
  die "chart missing"  unless $params{chart} && ref($params{chart}) eq 'SL::DB::Chart';
  die t8('Booking needs at least one debit and one credit booking!')
    unless $params{debit} or $params{credit}; # must exist and not be 0
  die t8('Cannot have a value in both Debit and Credit!')
    if defined($params{debit}) and defined($params{credit});

  my $chart = $params{chart};

  my $dec = delete $params{dec} // 2;

  my ($netamount,$taxamount) = (0,0);
  my $amount = $params{credit} // $params{debit}; # only one can exist

  croak t8('You cannot use a negative amount with debit/credit!') if $amount < 0;

  require SL::DB::Tax;

  my $ct        = $chart->get_active_taxkey($self->deliverydate // $self->transdate);
  my $chart_tax = ref $ct eq 'SL::DB::TaxKey' ? $ct->tax : undef;

  my $tax = defined($params{tax_id})        ? SL::DB::Manager::Tax->find_by(id => $params{tax_id}) # 1. user param
          : ref $chart_tax eq 'SL::DB::Tax' ? $chart_tax                                           # automatic tax
          : SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.00);                              # no tax

  die "No valid tax found. User input:" . $params{tax_id} unless ref $tax eq 'SL::DB::Tax';

  if ( $tax and $tax->rate != 0 ) {
    ($netamount, $taxamount) = Form->calculate_tax($amount, $tax->rate, $self->taxincluded, $dec);
  } else {
    $netamount = $amount;
  };

  if ( $params{debit} ) {
    $amount    *= -1;
    $netamount *= -1;
    $taxamount *= -1;
  };

  next unless $netamount; # skip entries with netamount 0

  # initialise transactions if it doesn't exist yet
  $self->transactions([]) unless $self->transactions;

  require SL::DB::AccTransaction;
  $self->add_transactions( SL::DB::AccTransaction->new(
    chart_id       => $chart->id,
    chart_link     => $chart->link,
    amount         => $netamount,
    taxkey         => $tax->taxkey,
    tax_id         => $tax->id,
    transdate      => $self->transdate,
    source         => $params{source} // '',
    memo           => $params{memo}   // '',
    ob_transaction => $self->ob_transaction,
    cb_transaction => $self->cb_transaction,
    project_id     => $params{project_id},
  ));

  # only add tax entry if amount is >= 0.01, defaults to 2 decimals
  if ( $::form->round_amount(abs($taxamount), $dec) > 0 ) {
    my $tax_chart = $tax->chart;
    if ( $tax->chart ) {
      $self->add_transactions(SL::DB::AccTransaction->new(
                                chart_id       => $tax_chart->id,
                                chart_link     => $tax_chart->link,
                                amount         => $taxamount,
                                taxkey         => $tax->taxkey,
                                tax_id         => $tax->id,
                                transdate      => $self->transdate,
                                ob_transaction => $self->ob_transaction,
                                cb_transaction => $self->cb_transaction,
                                source         => $params{source} // '',
                                memo           => $params{memo}   // '',
                                project_id     => $params{project_id},
                              ));
    };
  };
  return $self;
};

sub validate {
  my ($self) = @_;

  my @errors;

  if ( $self->transactions && scalar @{ $self->transactions } ) {
    my $debit_count  = map { $_->amount } grep { $_->amount > 0 } @{ $self->transactions };
    my $credit_count = map { $_->amount } grep { $_->amount < 0 } @{ $self->transactions };

    if ( $debit_count > 1 && $credit_count > 1 ) {
      push @errors, t8('Split entry detected. The values you have entered will result in an entry with more than one position on both debit and credit. ' .
                       'Due to known problems involving accounting software kivitendo does not allow these.');
    } elsif ( $credit_count == 0 && $debit_count == 0 ) {
      push @errors, t8('Booking needs at least one debit and one credit booking!');
    } else {
      # transactions formally ok, now check for out of balance:
      my $sum = sum map { $_->amount } @{ $self->transactions };
      # compare rounded amount to 0, to get around floating point problems, e.g.
      # $sum = -2.77555756156289e-17
      push @errors, t8('Out of balance transaction!') unless $::form->round_amount($sum,5) == 0;
    };
  } else {
    push @errors, t8('Empty transaction!');
  };

  # fields enforced by interface
  push @errors, t8('Reference missing!')   unless $self->reference;
  push @errors, t8('Description missing!') unless $self->description;

  # date checks
  push @errors, t8('Transaction Date missing!') unless $self->transdate && ref($self->transdate) eq 'DateTime';

  if ( $self->transdate ) {
    if ( $::form->date_closed( $self->transdate, \%::myconfig) ) {
      if ( !$self->id ) {
        push @errors, t8('Cannot post transaction for a closed period!')
      } else {
        push @errors, t8('Cannot change transaction in a closed period!')
      };
    };

    push @errors, t8('Cannot post transaction above the maximum future booking date!')
      if $::form->date_max_future($self->transdate, \%::myconfig);
  }

  return @errors;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SL::DB::GLTransaction: Rose model for GL transactions (table "gl")

=head1 FUNCTIONS

=over 4

=item C<post>

Takes an unsaved but initialised GLTransaction object and saves it, but first
validates the object, sets certain defaults (e.g. employee), and then also runs
various checks, writes history, runs DATEV check, ...

Returns C<$self> on success and dies otherwise. The whole process is run inside
a transaction. If it fails then nothing is saved to or changed in the database.
A new transaction is only started if none are active.

Example of posting a GL transaction from scratch:

  my $tax_0 = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.00);
  my $gl_transaction = SL::DB::GLTransaction->new(
    taxincluded => 1,
    description => 'bar',
    reference   => 'bla',
    transdate   => DateTime->today_local,
  )->add_chart_booking(
    chart  => SL::DB::Manager::Chart->find_by( description => 'Kasse' ),
    credit => 100,
    tax_id => $tax_0->id,
  )->add_chart_booking(
    chart  => SL::DB::Manager::Chart->find_by( description => 'Bank' ),
    debit  => 100,
    tax_id => $tax_0->id,
  )->post;

=item C<add_chart_booking %params>

Adds an acc_trans entry to an existing GL transaction, depending on the tax it
will also automatically create the tax entry. The GL transaction already needs
to have certain values, e.g. transdate, taxincluded, ...
Tax can be either set via the param tax_id or it will be set automatically
depending on the chart configuration. If not set and no configuration is found
no tax entry will be created (taxkey 0).

Mandatory params are

=over 2

=item * chart as an RDBO object

=item * either debit OR credit (positive values)

=back

Optional params:

=over 2

=item * dec - number of decimals to round to, defaults to 2

=item * source

=item * memo

=item * project_id

=back

All other values are taken directly from the GL transaction.

For an example, see C<post>.

After adding an acc_trans entry the GL transaction shouldn't be modified (e.g.
values affecting the acc_trans entries, such as transdate or taxincluded
shouldn't be changed). There is currently no method for recalculating the
acc_trans entries after they were added.

Return C<$self>, so it allows chaining.

=item C<validate>

Runs various checks to see if the GL transaction is ready to be C<post>ed.

Will return an array of error strings if any necessary conditions aren't met.

=back

=head1 TODO

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,
G. Richardson E<lt>grichardson@kivitec.deE<gt>

=cut
