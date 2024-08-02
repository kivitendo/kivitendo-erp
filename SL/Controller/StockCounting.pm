package SL::Controller::StockCounting;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Employee;
use SL::DB::StockCounting;
use SL::DB::StockCountingItem;

use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic(
  #scalar => [ qw() ],
  'scalar --get_set_init' => [ qw(is_developer countings stock_counting_item) ],
);

# check permissions
__PACKAGE__->run_before(sub { $::auth->assert('warehouse_management'); });

# load js
__PACKAGE__->run_before(sub { $::request->layout->add_javascripts('kivi.Validator.js', 'kivi.StockCounting.js'); });

################ actions #################

sub action_select_counting {
  my ($self) = @_;

  $self->render('stock_counting/select_counting');
}

sub action_start_counting {
  my ($self) = @_;

  $self->render('stock_counting/count');
}

sub action_count {
  my ($self) = @_;

  my @errors;
  push @errors, t8('EAN is missing')    if !$::form->{ean};

  return $self->render('stock_counting/count', errors => \@errors) if @errors;

  my $parts = SL::DB::Manager::Part->get_all(where => [ean => $::form->{ean},
                                                       or  => [obsolete => 0, obsolete => undef]]);
  push @errors, t8 ('Part not found')    if scalar(@$parts) == 0;
  push @errors, t8 ('Part is ambiguous') if scalar(@$parts) >  1;

  $self->stock_counting_item->part($parts->[0]) if !@errors;

  my @validation_errors = $self->stock_counting_item->validate;
  push @errors, @validation_errors if @validation_errors;

  $::form->error(join "\n", @errors) if @errors;

  $self->stock_counting_item->qty(1);
  $self->stock_counting_item->save;

  $self->render('stock_counting/count',);
}

sub init_is_developer {
  !!$::auth->assert('developer', 'may_fail')
}

sub init_countings {
  SL::DB::Manager::StockCounting->get_all_sorted;
}

sub init_stock_counting_item {
  SL::DB::StockCountingItem->new(%{$::form->{stock_counting_item}},
                                 employee => SL::DB::Manager::Employee->current);
}

1;
