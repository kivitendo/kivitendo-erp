package SL::Controller::LiquidityProjection;

use strict;

use parent qw(SL::Controller::Base);

use SL::Locale::String;
use SL::LiquidityProjection;
use SL::Util qw(_hashify);

__PACKAGE__->run_before('check_auth');

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(liquidity) ],
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
    parts_group       => 1,
  };

  $self->setup_show_action_bar;
  $self->render('liquidity_projection/show', title => t8('Liquidity projection'));
}

sub action_list_orders {
  my ($self) = @_;

  my @orders = SL::LiquidityProjection->orders_for_time_period(
    after  => $::form->{after}  ? DateTime->from_kivitendo($::form->{after})  : undef,
    before => $::form->{before} ? DateTime->from_kivitendo($::form->{before}) : undef,
  );

  $self->render(
    'liquidity_projection/list_orders',
    title  => t8('Sales Orders'),
    ORDERS => \@orders,
  );
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
  my $today   = DateTime->today_local->truncate(to => 'month');
  my %url_params;

  my $fields  = '';

  if ($reqdate eq 'old') {
    $url_params{before} = $today->to_kivitendo;

  } elsif ($reqdate eq 'future') {
    $url_params{after} = $today->add(months => $months)->to_kivitendo;

  } else {
    $reqdate            =~ m/(\d+)-(\d+)/;
    my $date            = DateTime->new_local(year => $1, month => $2, day => 1);
    $url_params{after}  = $date->to_kivitendo;
    $url_params{before} = $date->add(months => 1)->to_kivitendo;
  }

  return $self->url_for(action => 'list_orders', %url_params);
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
