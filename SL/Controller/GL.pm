package SL::Controller::GL;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::GLTransaction;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;
use SL::DB::AccTransaction;
use SL::Locale::String qw(t8);

__PACKAGE__->run_before('check_auth');

sub action_quicksearch {

  my ($self, %params) = @_;
  
  my $limit = $::form->{limit} || 40; # max number of results per type (AR/AP/GL)
  my $term  = $::form->{term}  || '';
  
  my $descriptionquery = { ilike => '%' . $term . '%' };
  my $referencequery   = { ilike => '%' . $term . '%' };
  my $apinvnumberquery = { ilike => '%' . $term . '%' };
  my $namequery        = { ilike => '%' . $term . '%' };
  my $arinvnumberquery = { ilike => '%' . $term       };
  # ar match is more restrictive. Left fuzzy beginning so it also matches "Storno zu $INVNUMBER"
  # and numbers like 000123 if you only enter 123.
  # When used in quicksearch short numbers like 1 or 11 won't match because of the
  # ajax autocomplete minlimit of 3 characters

  my (@glfilter, @arfilter, @apfilter);

  push( @glfilter, (or => [ description => $descriptionquery, reference => $referencequery ] ) );
  push( @arfilter, (or => [ invnumber   => $arinvnumberquery, name      => $namequery ] ) );
  push( @apfilter, (or => [ invnumber   => $apinvnumberquery, name      => $namequery ] ) );

  my $gls = SL::DB::Manager::GLTransaction->get_all(  query => [ @glfilter ], limit => $limit, sort_by => 'transdate DESC');
  my $ars = SL::DB::Manager::Invoice->get_all(        query => [ @arfilter ], limit => $limit, sort_by => 'transdate DESC', with_objects => [ 'customer' ]);
  my $aps = SL::DB::Manager::PurchaseInvoice->get_all(query => [ @apfilter ], limit => $limit, sort_by => 'transdate DESC', with_objects => [ 'vendor' ]);

  # calculate an amount to be displayed for gl transaction
  foreach my $gl ( @$gls ) {
    my $amount = 0;
    my $acc_trans_lines = SL::DB::Manager::AccTransaction->get_all(query => [ trans_id => $gl->id ]);
    foreach my $acc_trans_line ( @$acc_trans_lines ) {
      $amount += $acc_trans_line->amount if $acc_trans_line->amount > 0 ;
    };
    $gl->{'amount'} = $amount;
  };

  my $gldata = [
    map(
      {
        {
           transdate => DateTime->from_object(object => $_->transdate)->ymd(),
           label     => $_->abbreviation. ": " . $_->description . " " . $_->reference . " " . $::form->format_amount(\%::myconfig, $_->{'amount'},2). " (" . $_->transdate->to_lxoffice . ")" ,
           value     => '',
           url       => 'gl.pl?action=edit&id=' . $_->id,
        }
      }
      @{$gls}
    ),
  ];

  my $ardata = [
    map(
      {
        {
           transdate => DateTime->from_object(object => $_->transdate)->ymd(),
           label     => $_->abbreviation . ": " . $_->invnumber . "   " . $_->customer->name . " " . $::form->format_amount(\%::myconfig, $_->amount,2)  . " (" . $_->transdate->to_lxoffice . ")" ,
           value     => "",
           url       => ($_->invoice ? "is" : "ar" ) . '.pl?action=edit&id=' . $_->id,
        }
      }
      @{$ars}
    ),
  ];

  my $apdata = [
    map(
      {
        {
           transdate => DateTime->from_object(object => $_->transdate)->ymd(),
           label     => $_->abbreviation . ": " . $_->invnumber . " " . $_->vendor->name . " " . $::form->format_amount(\%::myconfig, $_->amount,2)  . " (" . $_->transdate->to_lxoffice . ")" ,
           value     => "",
           url       => ($_->invoice ? "ir" : "ap" ) . '.pl?action=edit&id=' . $_->id,
        }
      }
      @{$aps}
    ),
  ];

  my $data;
  push(@{$data},@{$gldata});
  push(@{$data},@{$ardata});
  push(@{$data},@{$apdata});

  @$data = reverse sort { $a->{'transdate_sort'} cmp $b->{'transdate_sort'} } @$data;

  $self->render(\SL::JSON::to_json($data), { layout => 0, type => 'json' });
}

sub check_auth {
  $::auth->assert('general_ledger');
}

1;
