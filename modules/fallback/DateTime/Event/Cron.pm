package DateTime::Event::Cron;

use 5.006;
use strict;
use warnings;
use Carp;

use vars qw($VERSION);

$VERSION = '0.08';

use constant DEBUG => 0;

use DateTime;
use DateTime::Set;
use Set::Crontab;

my %Object_Attributes;

###

sub from_cron {
  # Return cron as DateTime::Set
  my $class = shift;
  my %sparms = @_ == 1 ? (cron => shift) : @_;
  my %parms;
  $parms{cron}      = delete $sparms{cron};
  $parms{user_mode} = delete $sparms{user_mode};
  $parms{cron} or croak "Cron string parameter required.\n";
  my $dtc = $class->new(%parms);
  $dtc->as_set(%sparms);
}

sub from_crontab {
  # Return list of DateTime::Sets based on entries from
  # a crontab file.
  my $class = shift;
  my %sparms = @_ == 1 ? (file => shift) : @_;
  my $file = delete $sparms{file};
  delete $sparms{cron};
  my $fh = $class->_prepare_fh($file);
  my @cronsets;
  while (<$fh>) {
    chomp;
    my $set;
    eval { $set = $class->from_cron(%sparms, cron => $_) };
    push(@cronsets, $set) if ref $set && !$@;
  }
  @cronsets;
}

sub as_set {
  # Return self as DateTime::Set
  my $self = shift;
  my %sparms = @_;
  Carp::cluck "Recurrence callbacks overriden by ". ref $self . "\n"
    if $sparms{next} || $sparms{recurrence} || $sparms{previous};
  delete $sparms{next};
  delete $sparms{previous};
  delete $sparms{recurrence};
  $sparms{next}     = sub { $self->next(@_) };
  $sparms{previous} = sub { $self->previous(@_) };
  DateTime::Set->from_recurrence(%sparms);
}

###

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  my %parms = @_ == 1 ? (cron => shift) : @_;
  my $crontab = $self->_make_cronset(%parms);
  $self->_cronset($crontab);
  $self;
}

sub new_from_cron { new(@_) }

sub new_from_crontab {
  my $class = shift;
  my %parms = @_ == 1 ? (file => shift()) : @_;
  my $fh = $class->_prepare_fh($parms{file});
  delete $parms{file};
  my @dtcrons;
  while (<$fh>) {
    my $dtc;
    eval { $dtc = $class->new(%parms, cron => $_) };
    if (ref $dtc && !$@) {
      push(@dtcrons, $dtc);
      $parms{user_mode} = 1 if defined $dtc->user;
    }
  }
  @dtcrons;
}

###

sub _prepare_fh {
  my $class = shift;
  my $fh = shift;
  if (! ref $fh) {
    my $file = $fh;
    local(*FH);
    $fh = do { local *FH; *FH }; # doubled *FH avoids warning
    open($fh, "<$file")
      or croak "Error opening $file for reading\n";
  }
  $fh;
}

###

sub valid {
  # Is the given date valid according the current cron settings?
  my($self, $date) = @_;
  return if !$date || $date->second;
  $self->minute->contains($date->minute)      &&
  $self->hour->contains($date->hour)          &&
  $self->days_contain($date->day, $date->dow) &&
  $self->month->contains($date->month);
}

sub match {
  # Does the given date match the cron spec?
  my($self, $date) = @_;
  $date = DateTime->now unless $date;
  $self->minute->contains($date->minute)      &&
  $self->hour->contains($date->hour)          &&
  $self->days_contain($date->day, $date->dow) &&
  $self->month->contains($date->month);
}

### Return adjacent dates without altering original date

sub next {
  my($self, $date) = @_;
  $date = DateTime->now unless $date;
  $self->increment($date->clone);
}

sub previous {
  my($self, $date) = @_;
  $date = DateTime->now unless $date;
  $self->decrement($date->clone);
}

### Change given date to adjacent dates

sub increment {
  my($self, $date) = @_;
  $date = DateTime->now unless $date;
  return $date if $date->is_infinite;
  do {
    $self->_attempt_increment($date);
  } until $self->valid($date);
  $date;
}

sub decrement {
  my($self, $date) = @_;
  $date = DateTime->now unless $date;
  return $date if $date->is_infinite;
  do {
    $self->_attempt_decrement($date);
  } until $self->valid($date);
  $date;
}

###

sub _attempt_increment {
  my($self, $date) = @_;
  ref $date or croak "Reference to datetime object reqired\n";
  $self->valid($date) ?
    $self->_valid_incr($date) :
    $self->_invalid_incr($date);
}

sub _attempt_decrement {
  my($self, $date) = @_;
  ref $date or croak "Reference to datetime object reqired\n";
  $self->valid($date) ?
    $self->_valid_decr($date) :
    $self->_invalid_decr($date);
}

sub _valid_incr { shift->_minute_incr(@_) }

sub _valid_decr { shift->_minute_decr(@_) }

sub _invalid_incr {
  # If provided date is valid, return it. Otherwise return
  # nearest valid date after provided date.
  my($self, $date) = @_;
  ref $date or croak "Reference to datetime object reqired\n";

  print STDERR "\nI GOT: ", $date->datetime, "\n" if DEBUG;

  $date->truncate(to => 'minute')->add(minutes => 1)
    if $date->second;

  print STDERR "RND: ", $date->datetime, "\n" if DEBUG;

  # Find our greatest invalid unit and clip
  if (!$self->month->contains($date->month)) {
    $date->truncate(to => 'month');
  }
  elsif (!$self->days_contain($date->day, $date->dow)) {
    $date->truncate(to => 'day');
  }
  elsif (!$self->hour->contains($date->hour)) {
    $date->truncate(to => 'hour');
  }
  else {
    $date->truncate(to => 'minute');
  }

  print STDERR "BBT: ", $date->datetime, "\n" if DEBUG;

  return $date if $self->valid($date);

  print STDERR "ZZT: ", $date->datetime, "\n" if DEBUG;

  # Extraneous durations clipped. Start searching.
  while (!$self->valid($date)) {
    $date->add(months => 1) until $self->month->contains($date->month);
    print STDERR "MON: ", $date->datetime, "\n" if DEBUG;

    my $day_orig = $date->day;
    $date->add(days => 1) until $self->days_contain($date->day, $date->dow);
    $date->truncate(to => 'month') && next if $date->day < $day_orig;
    print STDERR "DAY: ", $date->datetime, "\n" if DEBUG;

    my $hour_orig = $date->hour;
    $date->add(hours => 1) until $self->hour->contains($date->hour);
    $date->truncate(to => 'day') && next if $date->hour < $hour_orig;
    print STDERR "HOR: ", $date->datetime, "\n" if DEBUG;

    my $min_orig = $date->minute;
    $date->add(minutes => 1) until $self->minute->contains($date->minute);
    $date->truncate(to => 'hour') && next if $date->minute < $min_orig;
    print STDERR "MIN: ", $date->datetime, "\n" if DEBUG;
  }
  print STDERR "SET: ", $date->datetime, "\n" if DEBUG;
  $date;
}

sub _invalid_decr {
  # If provided date is valid, return it. Otherwise
  # return the nearest previous valid date.
  my($self, $date) = @_;
  ref $date or croak "Reference to datetime object reqired\n";

  print STDERR "\nD GOT: ", $date->datetime, "\n" if DEBUG;

  if (!$self->month->contains($date->month)) {
    $date->truncate(to => 'month');
  }
  elsif (!$self->days_contain($date->day, $date->dow)) {
    $date->truncate(to => 'day');
  }
  elsif (!$self->hour->contains($date->hour)) {
    $date->truncate(to => 'hour');
  }
  else {
    $date->truncate(to => 'minute');
  }

  print STDERR "BBT: ", $date->datetime, "\n" if DEBUG;

  return $date if $self->valid($date);

  print STDERR "ZZT: ", $date->datetime, "\n" if DEBUG;

  # Extraneous durations clipped. Start searching.
  while (!$self->valid($date)) {
    if (!$self->month->contains($date->month)) {
      $date->subtract(months => 1) until $self->month->contains($date->month);
      $self->_unit_peak($date, 'month');
      print STDERR "MON: ", $date->datetime, "\n" if DEBUG;
    }
    if (!$self->days_contain($date->day, $date->dow)) {
      my $day_orig = $date->day;
      $date->subtract(days => 1)
        until $self->days_contain($date->day, $date->dow);
      $self->_unit_peak($date, 'month') && next if ($date->day > $day_orig);
      $self->_unit_peak($date, 'day');
      print STDERR "DAY: ", $date->datetime, "\n" if DEBUG;
    }
    if (!$self->hour->contains($date->hour)) {
      my $hour_orig = $date->hour;
      $date->subtract(hours => 1) until $self->hour->contains($date->hour);
      $self->_unit_peak($date, 'day') && next if ($date->hour > $hour_orig);
      $self->_unit_peak($date, 'hour');
      print STDERR "HOR: ", $date->datetime, "\n" if DEBUG;
    }
    if (!$self->minute->contains($date->minute)) {
      my $min_orig = $date->minute;
      $date->subtract(minutes => 1)
        until $self->minute->contains($date->minute);
      $self->_unit_peak($date, 'hour') && next if ($date->minute > $min_orig);
      print STDERR "MIN: ", $date->datetime, "\n" if DEBUG;
    }
  }
  print STDERR "SET: ", $date->datetime, "\n" if DEBUG;
  $date;
}

###

sub _unit_peak {
  my($self, $date, $unit) = @_;
  $date && $unit or croak "DateTime ref and unit required.\n";
  $date->truncate(to => $unit)
       ->add($unit . 's' => 1)
       ->subtract(minutes => 1);
}

### Unit cascades

sub _minute_incr {
  my($self, $date) = @_;
  croak "datetime object required\n" unless $date;
  my $cur = $date->minute;
  my $next = $self->minute->next($cur);
  $date->set(minute => $next);
  $next <= $cur ? $self->_hour_incr($date) : $date;
}

sub _hour_incr {
  my($self, $date) = @_;
  croak "datetime object required\n" unless $date;
  my $cur = $date->hour;
  my $next = $self->hour->next($cur);
  $date->set(hour => $next);
  $next <= $cur ? $self->_day_incr($date) : $date;
}

sub _day_incr {
  my($self, $date) = @_;
  croak "datetime object required\n" unless $date;
  $date->add(days => 1);
  $self->_invalid_incr($date);
}

sub _minute_decr {
  my($self, $date) = @_;
  croak "datetime object required\n" unless $date;
  my $cur = $date->minute;
  my $next = $self->minute->previous($cur);
  $date->set(minute => $next);
  $next >= $cur ? $self->_hour_decr($date) : $date;
}

sub _hour_decr {
  my($self, $date) = @_;
  croak "datetime object required\n" unless $date;
  my $cur = $date->hour;
  my $next = $self->hour->previous($cur);
  $date->set(hour => $next);
  $next >= $cur ? $self->_day_decr($date) : $date;
}

sub _day_decr {
  my($self, $date) = @_;
  croak "datetime object required\n" unless $date;
  $date->subtract(days => 1);
  $self->_invalid_decr($date);
}

### Factories

sub _make_cronset { shift; DateTime::Event::Cron::IntegratedSet->new(@_) }

### Shortcuts

sub days_contain { shift->_cronset->days_contain(@_) }

sub minute   { shift->_cronset->minute  }
sub hour     { shift->_cronset->hour    }
sub day      { shift->_cronset->day     }
sub month    { shift->_cronset->month   }
sub dow      { shift->_cronset->dow     }
sub user     { shift->_cronset->user    }
sub command  { shift->_cronset->command }
sub original { shift->_cronset->original }

### Static acessors/mutators

sub _cronset { shift->_attr('cronset', @_) }

sub _attr {
  my $self = shift;
  my $name = shift;
  if (@_) {
    $Object_Attributes{$self}{$name} = shift;
  }
  $Object_Attributes{$self}{$name};
}

### debugging

sub _dump_sets {
  my($self, $date) = @_;
  foreach (qw(minute hour day month dow)) {
    print STDERR "$_: ", join(',',$self->$_->list), "\n";
  }
  if (ref $date) {
    $date = $date->clone;
    my @mod;
    my $mon = $date->month;
    $date->truncate(to => 'month');
    while ($date->month == $mon) {
      push(@mod, $date->day) if $self->days_contain($date->day, $date->dow);
      $date->add(days => 1);
    }
    print STDERR "mod for month($mon): ", join(',', @mod), "\n";
  }
  print STDERR "day_squelch: ", $self->_cronset->day_squelch, " ",
               "dow_squelch: ", $self->_cronset->dow_squelch, "\n";
  $self;
}

###

sub DESTROY { delete $Object_Attributes{shift()} }

##########

{

package DateTime::Event::Cron::IntegratedSet;

# IntegratedSet manages the collection of field sets for
# each cron entry, including sanity checks. Individual
# field sets are accessed through their respective names,
# i.e., minute hour day month dow.
#
# Also implements some merged field logic for day/dow
# interactions.

use strict;
use Carp;

my %Range = (
  minute => [0..59],
  hour   => [0..23],
  day    => [1..31],
  month  => [1..12],
  dow    => [1..7],
);

my @Month_Max = qw( 31 29 31 30 31 30 31 31 30 31 30 31 );

my %Object_Attributes;

sub new {
  my $self = [];
  bless $self, shift;
  $self->_range(\%Range);
  $self->set_cron(@_);
  $self;
}

sub set_cron {
  # Initialize
  my $self = shift;
  my %parms = @_;
  my $cron = $parms{cron};
  my $user_mode = $parms{user_mode};
  defined $cron or croak "Cron entry fields required\n";
  $self->_attr('original', $cron);
  my @line;
  if (ref $cron) {
    @line = grep(!/^\s*$/, @$cron);
  }
  else {
    $cron =~ s/^\s+//;
    $cron =~ s/\s+$//;
    @line = split(/\s+/, $cron);
  }
  @line >= 5 or croak "At least five cron entry fields required.\n";
  my @entry = splice(@line, 0, 5);
  my($user, $command);
  unless (defined $user_mode) {
    # auto-detect
    if (@line > 1 && $line[0] =~ /^\w+$/) {
      $user_mode = 1;
    }
  }
  $user = shift @line if $user_mode;
  $command = join(' ', @line);
  $self->_attr('command', $command);
  $self->_attr('user', $user);
  my $i = 0;
  foreach my $name (qw( minute hour day month dow )) {
    $self->_attr($name, $self->make_valid_set($name, $entry[$i]));
    ++$i;
  }
  my @day_list  = $self->day->list;
  my @dow_list  = $self->dow->list;
  my $day_range = $self->range('day');
  my $dow_range = $self->range('dow');
  $self->day_squelch(scalar @day_list == scalar @$day_range &&
                     scalar @dow_list != scalar @$dow_range ? 1 : 0);
  $self->dow_squelch(scalar @dow_list == scalar @$dow_range &&
                     scalar @day_list != scalar @$day_range ? 1 : 0);
  unless ($self->day_squelch) {
    my @days = $self->day->list;
    my $pass = 0;
    MONTH: foreach my $month ($self->month->list) {
      foreach (@days) {
        ++$pass && last MONTH if $_ <= $Month_Max[$month - 1];
      }
    }
    croak "Impossible last day for provided months.\n" unless $pass;
  }
  $self;
}

# Field range queries
sub range {
  my($self, $name) = @_;
  my $val = $self->_range->{$name} or croak "Unknown field '$name'\n";
  $val;
}

# Perform sanity checks when setting up each field set.
sub make_valid_set {
  my($self, $name, $str) = @_;
  my $range = $self->range($name);
  my $set = $self->make_set($str, $range);
  my @list = $set->list;
  croak "Malformed cron field '$str'\n" unless @list;
  croak "Field value ($list[-1]) out of range ($range->[0]-$range->[-1])\n"
    if $list[-1] > $range->[-1];
  if ($name eq 'dow' && $set->contains(0)) {
    shift(@list);
    push(@list, 7) unless $set->contains(7);
    $set = $self->make_set(join(',',@list), $range);
  }
  croak "Field value ($list[0]) out of range ($range->[0]-$range->[-1])\n"
    if $list[0] < $range->[0];
  $set;
}

# No sanity checks
sub make_set { shift; DateTime::Event::Cron::OrderedSet->new(@_) }

# Flags for when day/dow are applied.
sub day_squelch { shift->_attr('day_squelch', @_ ) }
sub dow_squelch { shift->_attr('dow_squelch', @_ ) }

# Merged logic for day/dow
sub days_contain {
  my($self, $day, $dow) = @_;
  defined $day && defined $dow
    or croak "Day of month and day of week required.\n";
  my $day_c = $self->day->contains($day);
  my $dow_c = $self->dow->contains($dow);
  return $dow_c if $self->day_squelch;
  return $day_c if $self->dow_squelch;
  $day_c || $dow_c;
}

# Set Accessors
sub minute   { shift->_attr('minute' ) }
sub hour     { shift->_attr('hour'   ) }
sub day      { shift->_attr('day'    ) }
sub month    { shift->_attr('month'  ) }
sub dow      { shift->_attr('dow'    ) }
sub user     { shift->_attr('user'   ) }
sub command  { shift->_attr('command') }
sub original { shift->_attr('original') }

# Accessors/mutators
sub _range       { shift->_attr('range', @_) }

sub _attr {
  my $self = shift;
  my $name = shift;
  if (@_) {
    $Object_Attributes{$self}{$name} = shift;
  }
  $Object_Attributes{$self}{$name};
}

sub DESTROY { delete $Object_Attributes{shift()} }

}

##########

{

package DateTime::Event::Cron::OrderedSet;

# Extends Set::Crontab with some progression logic (next/prev)

use strict;
use Carp;
use base 'Set::Crontab';

my %Object_Attributes;

sub new {
  my $class = shift;
  my($string, $range) = @_;
  defined $string && ref $range
    or croak "Cron field and range ref required.\n";
  my $self = Set::Crontab->new($string, $range);
  bless $self, $class;
  my @list = $self->list;
  my(%next, %prev);
  foreach (0 .. $#list) {
    $next{$list[$_]} = $list[($_+1)%@list];
    $prev{$list[$_]} = $list[($_-1)%@list];
  }
  $self->_attr('next', \%next);
  $self->_attr('previous', \%prev);
  $self;
}

sub next {
  my($self, $entry) = @_;
  my $hash = $self->_attr('next');
  croak "Missing entry($entry) in set\n" unless exists $hash->{$entry};
  my $next = $hash->{$entry};
  wantarray ? ($next, $next <= $entry) : $next;
}

sub previous {
  my($self, $entry) = @_;
  my $hash = $self->_attr('previous');
  croak "Missing entry($entry) in set\n" unless exists $hash->{$entry};
  my $prev = $hash->{$entry};
  wantarray ? ($prev, $prev >= $entry) : $prev;
}

sub _attr {
  my $self = shift;
  my $name = shift;
  if (@_) {
    $Object_Attributes{$self}{$name} = shift;
  }
  $Object_Attributes{$self}{$name};
}

sub DESTROY { delete $Object_Attributes{shift()} }

}

###

1;

__END__

=head1 NAME

DateTime::Event::Cron - DateTime extension for generating recurrence
sets from crontab lines and files.

=head1 SYNOPSIS

  use DateTime::Event::Cron;

  # check if a date matches (defaults to current time)
  my $c = DateTime::Event::Cron->new('* 2 * * *');
  if ($c->match) {
    # do stuff
  }
  if ($c->match($date)) {
    # do something else for datetime $date
  }

  # DateTime::Set construction from crontab line
  $crontab = '*/3 15 1-10 3,4,5 */2';
  $set = DateTime::Event::Cron->from_cron($crontab);
  $iter = $set->iterator(after => DateTime->now);
  while (1) {
    my $next = $iter->next;
    my $now  = DateTime->now;
    sleep(($next->subtract_datetime_absolute($now))->seconds);
    # do stuff...
  }

  # List of DateTime::Set objects from crontab file
  @sets = DateTime::Event::Cron->from_crontab(file => '/etc/crontab');
  $now = DateTime->now;
  print "Now: ", $now->datetime, "\n";
  foreach (@sets) {
    my $next = $_->next($now);
    print $next->datetime, "\n";
  }

  # DateTime::Set parameters
  $crontab = '* * * * *';

  $now = DateTime->now;
  %set_parms = ( after => $now );
  $set = DateTime::Event::Cron->from_cron(cron => $crontab, %set_parms);
  $dt = $set->next;
  print "Now: ", $now->datetime, " and next: ", $dt->datetime, "\n";

  # Spans for DateTime::Set
  $crontab = '* * * * *';
  $now = DateTime->now;
  $now2 = $now->clone;
  $span = DateTime::Span->from_datetimes(
            start => $now->add(minutes => 1),
	    end   => $now2->add(hours => 1),
	  );
  %parms = (cron => $crontab, span => $span);
  $set = DateTime::Event::Cron->from_cron(%parms);
  # ...do things with the DateTime::Set

  # Every RTFCT relative to 12am Jan 1st this year
  $crontab = '7-10 6,12-15 10-28/2 */3 3,4,5';
  $date = DateTime->now->truncate(to => 'year');
  $set = DateTime::Event::Cron->from_cron(cron => $crontab, after => $date);

  # Rather than generating DateTime::Set objects, next/prev
  # calculations can be made directly:

  # Every day at 10am, 2pm, and 6pm. Reference date
  # defaults to DateTime->now.
  $crontab = '10,14,18 * * * *';
  $dtc = DateTime::Event::Cron->new_from_cron(cron => $crontab);
  $next_datetime = $dtc->next;
  $last_datetime = $dtc->previous;
  ...

  # List of DateTime::Event::Cron objects from
  # crontab file
  @dtc = DateTime::Event::Cron->new_from_crontab(file => '/etc/crontab');

  # Full cron lines with user, such as from /etc/crontab
  # or files in /etc/cron.d, are supported and auto-detected:
  $crontab = '* * * * * gump /bin/date';
  $dtc = DateTime::Event::Cron->new(cron => $crontab);

  # Auto-detection of users is disabled if you explicitly
  # enable/disable via the user_mode parameter:
  $dtc = DateTime::Event::Cron->new(cron => $crontab, user_mode => 1);
  my $user = $dtc->user;
  my $command = $dtc->command;

  # Unparsed original cron entry
  my $original = $dtc->original;

=head1 DESCRIPTION

DateTime::Event::Cron generated DateTime events or DateTime::Set objects
based on crontab-style entries.

=head1 METHODS

The cron fields are typical crontab-style entries. For more information,
see L<crontab(5)> and extensions described in L<Set::Crontab>. The
fields can be passed as a single string or as a reference to an array
containing each field. Only the first five fields are retained.

=head2 DateTime::Set Factories

See L<DateTime::Set> for methods provided by Set objects, such as
C<next()> and C<previous()>.

=over 4

=item from_cron($cronline)

=item from_cron(cron => $cronline, %parms, %set_parms)

Generates a DateTime::Set recurrence for the cron line provided. See
new() for details on %parms. Optionally takes parameters for
DateTime::Set.

=item from_crontab(file => $crontab_fh, %parms, %set_parms)

Returns a list of DateTime::Set recurrences based on lines from a
crontab file. C<$crontab_fh> can be either a filename or filehandle
reference. See new() for details on %parm. Optionally takes parameters
for DateTime::Set which will be passed along to each set for each line.

=item as_set(%set_parms)

Generates a DateTime::Set recurrence from an existing
DateTime::Event::Cron object.

=back

=head2 Constructors

=over 4

=item new_from_cron(cron => $cronstring, %parms)

Returns a DateTime::Event::Cron object based on the cron specification.
Optional parameters include the boolean 'user_mode' which indicates that
the crontab entry includes a username column before the command.

=item new_from_crontab(file => $fh, %parms)

Returns a list of DateTime::Event::Cron objects based on the lines of a
crontab file. C<$fh> can be either a filename or a filehandle reference.
Optional parameters include the boolean 'user_mode' as mentioned above.

=back

=head2 Other methods

=over 4

=item next()

=item next($date)

Returns the next valid datetime according to the cron specification.
C<$date> defaults to DateTime->now unless provided.

=item previous()

=item previous($date)

Returns the previous valid datetime according to the cron specification.
C<$date> defaults to DateTime->now unless provided.

=item increment($date)

=item decrement($date)

Same as C<next()> and C<previous()> except that the provided datetime is
modified to the new datetime.

=item match($date)

Returns whether or not the given datetime (defaults to current time)
matches the current cron specification. Dates are truncated to minute
resolution.

=item valid($date)

A more strict version of match(). Returns whether the given datetime is
valid under the current cron specification. Cron dates are only accurate
to the minute -- datetimes with seconds greater than 0 are invalid by
default. (note: never fear, all methods accepting dates will accept
invalid dates -- they will simply be rounded to the next nearest valid
date in all cases except this particular method)

=item command()

Returns the command string, if any, from the original crontab entry.
Currently no expansion is performed such as resolving environment
variables, etc.

=item user()

Returns the username under which this cron command was to be executed,
assuming such a field was present in the original cron entry.

=item original()

Returns the original, unparsed cron string including any user or
command fields.

=back

=head1 AUTHOR

Matthew P. Sisk E<lt>sisk@mojotoad.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2003 Matthew P. Sisk. All rights reserved. All wrongs
revenged. This program is free software; you can distribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

DateTime(3), DateTime::Set(3), DateTime::Event::Recurrence(3),
DateTime::Event::ICal(3), DateTime::Span(3), Set::Crontab(3), crontab(5)

=cut
