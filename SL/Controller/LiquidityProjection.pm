package SL::Controller::LiquidityProjection;

use strict;

use parent qw(SL::Controller::Base);

use SL::Locale::String;
use SL::LiquidityProjection;
use SL::Util qw(_hashify);

__PACKAGE__->run_before('check_auth');

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(liquidity) ],
  'scalar --get_set_init' => [ qw(oe_report_columns_str) ],
);


#
# actions
#

sub action_show {
  my ($self) = @_;

  $self->liquidity(SL::LiquidityProjection->new(%{ $::form->{params} })->create) if $::form->{params};

  $::form->{params} ||= {
    months            => 6,
    type              => 1,
    salesman          => 1,
    buchungsgruppe    => 1,
  };

  $self->setup_show_action_bar;
  $self->render('liquidity_projection/show', title => t8('Liquidity projection'));
}

#
# filters
#

sub check_auth                 { $::auth->assert('report') }
sub init_oe_report_columns_str { join '&', map { "$_=Y" } qw(open delivered notdelivered l_ordnumber l_transdate l_reqdate l_name l_employee l_salesman l_netamount l_amount l_transaction_description) }

#
# helpers
#

sub link_to_old_orders {
  my $self    = shift;
  my %params  = _hashify(0, @_);

  my $reqdate = $params{reqdate};
  my $months  = $params{months} * 1;

  my $fields  = '';

  if ($reqdate eq 'old') {
    $fields .= '&reqdate_unset_or_old=Y';

  } elsif ($reqdate eq 'future') {
    my @now  = localtime;
    $fields .= '&reqdatefrom=' . $self->iso_to_display(SL::LiquidityProjection::_the_date($now[5] + 1900, $now[4] + 1 + $months) . '-01');

  } else {
    $reqdate =~ m/(\d+)-(\d+)/;
    $fields .=  '&reqdatefrom=' . $self->iso_to_display($reqdate . '-01');
    $fields .=  '&reqdateto='   . $self->iso_to_display($reqdate . sprintf('-%02d', DateTime->last_day_of_month(year => $1, month => $2)->day));

  }

  return "oe.pl?action=orders&type=sales_order&vc=customer&" . $self->oe_report_columns_str . $fields;
}

sub iso_to_display {
  my ($self, $date) = @_;

  $::locale->reformat_date({ dateformat => 'yyyy-mm-dd' }, $date, $::myconfig{dateformat});
}

sub setup_show_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#filter_form', { action => 'LiquidityProjection/show' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
