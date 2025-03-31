use Test::More tests => 11;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;

use SL::DB::Manager::EmailJournal;

use SL::Dev::ALL qw(:ALL);
use SL::Dev::EmailJournal qw(:ALL);

Support::TestSetup::login();

sub clear_up {
  foreach (qw(
    EmailJournalAttachment
    EmailJournal
    Order
    )) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
};

clear_up();

my $email_journal_1 = create_email_journal()->save();
my $attachment = create_attachment($email_journal_1)->save();
my $sales_order = create_sales_order()->save();
$email_journal_1->link_to_record($sales_order);

my $email_journal_2 = create_email_journal()->save();

my ($found_emails, $key, $value, $with_objects);
eval { # has_unprocessed_attachments

  ($key, $value, $with_objects) = SL::DB::Manager::EmailJournal->filter('has_unprocessed_attachments', 1, '');

  $found_emails = SL::DB::Manager::EmailJournal->get_all(
    where => [ $key => $value, ],
    with_objects => $with_objects
  );

  ok scalar @$found_emails == 1, 'has_unprocessed_attachments 1 find email';
  ok $found_emails->[0]->id == $email_journal_1->id, 'has_unprocessed_attachments 1 find correct email';

  ($key, $value, $with_objects) = SL::DB::Manager::EmailJournal->filter('has_unprocessed_attachments', 0, '');

  $found_emails = SL::DB::Manager::EmailJournal->get_all(
    where => [ $key => $value, ],
    with_objects => $with_objects
  );

  ok scalar @$found_emails == 1, 'has_unprocessed_attachments 0 find email';
  ok $found_emails->[0]->id == $email_journal_2->id, 'has_unprocessed_attachments 0 find correct email';
};

eval { # linked_to
  ($key, $value, $with_objects) = SL::DB::Manager::EmailJournal->filter('linked_to', 1, '');

  $found_emails = SL::DB::Manager::EmailJournal->get_all(
    where => [ $key => $value, ],
    with_objects => $with_objects
  );

  ok scalar @$found_emails == 1, 'linked_to 1 find email';
  ok $found_emails->[0]->id == $email_journal_1->id, 'linked_to 1 find correct email';

  ($key, $value, $with_objects) = SL::DB::Manager::EmailJournal->filter('linked_to', 0, '');

  $found_emails = SL::DB::Manager::EmailJournal->get_all(
    where => [ $key => $value, ],
    with_objects => $with_objects
  );

  ok scalar @$found_emails == 1, 'linked_to 0 find email';
  ok $found_emails->[0]->id == $email_journal_2->id, 'linked_to 0 find correct email';
};

eval { # unprocessed_attachment_names
  ($key, $value, $with_objects) = SL::DB::Manager::EmailJournal->filter('unprocessed_attachment_names', $attachment->name, '');

  $found_emails = SL::DB::Manager::EmailJournal->get_all(
    where => [ $key => $value, ],
    with_objects => $with_objects
  );

  ok scalar @$found_emails == 1, 'unprocessed_attachment_names 1 find email';
  ok $found_emails->[0]->id == $email_journal_1->id, 'unprocessed_attachment_names 1 find correct email';

  ($key, $value, $with_objects) = SL::DB::Manager::EmailJournal->filter('unprocessed_attachment_names', 'foo', '');

  $found_emails = SL::DB::Manager::EmailJournal->get_all(
    where => [ $key => $value, ],
    with_objects => $with_objects
  );

  ok scalar @$found_emails == 0, 'unprocessed_attachment_names 0 find email';
};

clear_up();

done_testing();
