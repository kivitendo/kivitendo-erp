package SL::Helper::QrBillFunctions;

use List::Util qw(first);

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(get_qrbill_account assemble_ref_number get_ref_number_formatted
  get_iban_formatted get_amount_formatted);

sub get_qrbill_account {
  $main::lxdebug->enter_sub();

  my $qr_account;

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all_sorted;
  
  $qr_account = first { $_->use_for_qrbill } @{ $bank_accounts };

  if (!$qr_account) {
    return undef, $::locale->text('No bank account flagged for QRBill usage was found.');
  }

  $main::lxdebug->leave_sub();
  return $qr_account, undef;
}

sub assemble_ref_number {
  $main::lxdebug->enter_sub();

  my $bank_id = $_[0];
  my $customer_number = $_[1];
  my $invoice_number = $_[2] // "0";

  # check values (analog to checks in makro)
  # - bank_id
  #     in-/output: a string containing a 6 digit number
  if (!($bank_id =~ /^\d*$/) || length($bank_id) != 6) {
    return undef, $::locale->text('Bank account id number invalid. Must be 6 digits.');
  }

  # - customer_number
  #     input: a string containing up to 6 digits [0-9]
  #     output: non-digits removed, 6 digits, filled with leading zeros
  $customer_number = remove_non_digits($customer_number);
  if (!check_digits_and_max_length($customer_number, 6)) {
    return undef, $::locale->text('Customer number invalid. Must be less then or equal to 6 digits after non-digits removed.');
  }
  # fill with zeros
  $customer_number = sprintf "%06d", $customer_number;

  # - invoice_number
  #     input: a string containing up to 14 digits, may be zero
  #     output: non-digits removed, 14 digits, filled with leading zeros
  $invoice_number = remove_non_digits($invoice_number);
  if (!check_digits_and_max_length($invoice_number, 14)) {
    return undef, $::locale->text('Invoice number invalid. Must be less then or equal to 14 digits after non-digits removed.');
  }
  # fill with zeros
  $invoice_number = sprintf "%014d", $invoice_number;

  # assemble ref. number
  my $ref_number = $bank_id . $customer_number . $invoice_number;

  # calculate check digit
  my $ref_number_cpl = $ref_number . calculate_check_digit($ref_number);

  $main::lxdebug->leave_sub();
  return $ref_number_cpl, undef;
}

sub get_ref_number_formatted {
  $main::lxdebug->enter_sub();

  my $ref_number = $_[0];

  # create ref. number in format:
  # 'XX XXXXX XXXXX XXXXX XXXXX XXXXX' (2 digits + 5 x 5 digits)
  my $ref_number_spaced = substr($ref_number, 0, 2) . ' ' .
                          substr($ref_number, 2, 5) . ' ' .
                          substr($ref_number, 7, 5) . ' ' .
                          substr($ref_number, 12, 5) . ' ' .
                          substr($ref_number, 17, 5) . ' ' .
                          substr($ref_number, 22, 5);

  $main::lxdebug->leave_sub();
  return $ref_number_spaced;
}

sub get_iban_formatted {
  $main::lxdebug->enter_sub();

  my $iban = $_[0];

  # create iban number in format:
  # 'XXXX XXXX XXXX XXXX XXXX X' (5 x 4 + 1digits)
  my $iban_spaced = substr($iban, 0, 4) . ' ' .
                    substr($iban, 4, 4) . ' ' .
                    substr($iban, 8, 4) . ' ' .
                    substr($iban, 12, 4) . ' ' .
                    substr($iban, 16, 4) . ' ' .
                    substr($iban, 20, 1);

  $main::lxdebug->leave_sub();
  return $iban_spaced;
}

sub get_amount_formatted {
  $main::lxdebug->enter_sub();

  my $amount = $_[0];

  # parameter should be a string containing a number
  # with 2 digits after the pointi'm also getting in the town 
  unless ($amount =~ /^\d+\.\d{2}$/) {
    return undef;
  }

  my $r = reverse $amount;
  # this matches the digits left of the '.'
  $r =~ m/^\d{2}\./g;
  # '\G' continuous the search where the last stopped,
  # matches three digits and substitutes with a space
  $r =~ s/\G(\d{3})(?=\d)/$1 /g;
  $r = reverse $r;

  $main::lxdebug->leave_sub();
  return $r;
}

### internal functions

sub remove_non_digits {
  my $s = $_[0];
  $s =~ s/[^0-9]//g;
  return $s;
}

sub check_digits_and_max_length {
  my $s = $_[0];
  my $length = $_[1];

  return 0 if (!($s =~ /^\d*$/) || length($s) > $length);
  return 1;
}

sub calculate_check_digit {
  # calculate ESR check digit using algorithm: "modulo 10, recursive"
  my $ref_number_str = $_[0];

  my @m = (0, 9, 4, 6, 8, 2, 7, 1, 3, 5);
  my $carry = 0;

  my @ref_number_split = map int($_), split(//, $ref_number_str);

  for my $v (@ref_number_split) {
    $carry = @m[($carry + $v) % 10];
  }

  return (10 - $carry) % 10;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::QrBillFunctions - Additional helper functions for the swiss QR bill

=head1 SYNOPSIS

  use SL::Helper::QrBillFunctions qw(get_qrbill_account assemble_ref_number
    get_ref_number_formatted get_iban_formatted get_amount_formatted);

  # get qr-account data
  my ($qr_account, $error) = get_qrbill_account();

  my ($ref_number, $error) = assemble_ref_number(
    $qr_account->{'bank_account_id'},
    $form->{'customernumber'},
    $form->{'invnumber'},
  );

  # get ref. number/iban formatted with spaces and set into form for template
  # processing
  $form->{'ref_number_formatted'} = get_ref_number_formatted($ref_number);
  $form->{'iban_formatted'} = get_iban_formatted($qr_account->{'iban'});

  # format amount for template
  my $amount = sprintf("%.2f", $form->parse_amount(\%::myconfig, $form->{'total'}));
  my $amount_formatted = get_amount_formatted($amount);

=head1 DESCRIPTION

Helper functions moved from SL::Template::OpenDocument.

=head1 FUNCTIONS

=over 4

=item C<get_qrbill_account>

Return the bank account flagged for the QR bill. And a string containing an
error message as second return value or undef if no error occurred.

=item C<assemble_ref_number>

Assembles and returns the Swiss reference number. 27 digits, formed
from the parameters plus one check digit. And a string containing an error
message as second return value or undef if no error occurred.

Non-digits will be removed and remaining numbers filled up with leading zeros.

Parameters:

=over 4

=item C<bank_id>

"Bankkonto Identifikationsnummer". A string containing a 6 digit number.

=item C<customer_number>

Kivitendo customer number. A string containing up to 6 digits.

=item C<invoice_number>

Kivitendo invoice number. A string containing up to 14 digits, may be zero.

=back

=item C<get_ref_number_formatted>

Given a reference number, return it in format:

'XX XXXXX XXXXX XXXXX XXXXX XXXXX' (2 digits + 5 x 5 digits)

=item C<get_iban_formatted>

Given a IBAN number, return it in format:

'XXXX XXXX XXXX XXXX XXXX X' (5 x 4 + 1digits)

=item C<get_amount_formatted>

Given an amount, return it in format: 'X XXX.XX'
Or undef if an error occurred.

=back

=head1 ERROR HANDLING

The functions C<get_qrbill_account> and C<assemble_ref_number> return
undef when an error occurs and a string containing an error message as
second return value.

The function C<get_amount_formatted> returns undef if an error occurred.

The other functions always return a result.

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@gmx.chE<gt>

=cut
