use Test::More tests => 40;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Test::Exception;
use DateTime;

use_ok 'SL::DB::TimeRecording';

use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();

my @time_recordings;
my ($s1, $e1, $s2, $e2);

sub clear_up {
  foreach (qw(TimeRecording Customer)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ '!login' => 'unittests' ]);
};

########################################

$s1 = DateTime->now_local;
$e1 = $s1->clone;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1);

ok( $time_recordings[0]->is_time_in_wrong_order, 'same start and end detected' );
ok( !$time_recordings[0]->is_time_overlapping, 'not overlapping if only one time recording entry in db' );

###
$time_recordings[0]->end_time(undef);
ok( !$time_recordings[0]->is_time_in_wrong_order, 'order ok if no end' );

########################################
# ------------s1-----e1-----
# --s2---e2-----------------
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 11, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2)->save;

ok( !$time_recordings[0]->is_time_overlapping, 'not overlapping: completely before 1' );
ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: completely before 2' );


# -------s1-----e1----------
# --s2---e2-----------------
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2)->save;

ok( !$time_recordings[0]->is_time_overlapping, 'not overlapping: before 1' );
ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: before 2' );

# ---s1-----e1--------------
# ---------------s2---e2----
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 13, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2)->save;

ok( !$time_recordings[0]->is_time_overlapping, 'not overlapping: completely after 1' );
ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: completely after 2' );

# ---s1-----e1--------------
# ----------s2---e2---------
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2)->save;

ok( !$time_recordings[0]->is_time_overlapping, 'not overlapping: after 1' );
ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: after 2' );

# -------s1-----e1----------
# ---s2-----e2--------------
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour =>  9, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: start before, end inbetween' );

# -------s1-----e1----------
# -----------s2-----e2------
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: start inbetween, end after' );

# ---s1---------e1----------
# ------s2---e2-------------
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: completely inbetween' );


# ------s1---e1-------------
# ---s2---------e2----------
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: completely oudside' );


# ---s1---e1----------------
# ---s2---------e2----------
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: same start, end outside' );

# ---s1------e1-------------
# ------s2---e2-------------
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: start after, same end' );

# ---s1------e1-------------
# ------s2------------------
# e2 undef
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: start inbetween, no end' );

# ---s1------e1-------------
# ---s2---------------------
# e2 undef
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: same start, no end' );

# -------s1------e1---------
# ---s2---------------------
# e2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: start before, no end' );

# -------s1------e1---------
# -------------------s2-----
# e2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 16, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: start after, no end' );

# -------s1------e1---------
# ---------------s2---------
# e2 undef
# -> does not overlap

$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: same start as other end, no end' );

# -------s1------e1---------
# -----------e2-------------
# s2 undef
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: no start, end inbetween' );

# -------s1------e1---------
# ---------------e2---------
# s2 undef
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: no start, same end' );

# -------s1------e1---------
# --e2----------------------
# s2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no start, end before' );

# -------s1------e1---------
# -------------------e2-----
# s2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 17, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no start, end after' );

# -------s1------e1---------
# -------e2-----------------
# s2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no start, same end as other start' );

# ----s1--------------------
# ----s2-----e2-------------
# e1 undef
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: no end in db, same start' );

# --------s1----------------
# ----s2-----e2-------------
# e1 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, enclosing' );

# ---s1---------------------
# ---------s2-----e2--------
# e1 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = undef;
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, completely after' );

# ---------s1---------------
# --------------------------
# e1, s2, e2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = undef;
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, no times in object' );

# ---------s1---------------
# -----s2-------------------
# e1, e2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, start before, no end in object' );

# ---------s1---------------
# -------------s2-----------
# e1, e2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, start after, no end in object' );

# ---------s1---------------
# ---------s2---------------
# e1, e2 undef
# -> overlaps
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e2 = undef;

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping: no end in db, same start' );

# ---------s1---------------
# ---e2---------------------
# e1, s2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, no start in object, end before' );

# ---------s1---------------
# ---------------e2---------
# e1, s2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, no start in object, end after' );

# ---------s1---------------
# ---------e2---------------
# e1, s2 undef
# -> does not overlap
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);
$e1 = undef;
$s2 = undef;
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 12, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping: no end in db, no start in object, same end' );

########################################
# not overlapping if different staff_member
$s1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 10, minute => 0);
$e1 = DateTime->new(year => 2020, month => 11, day => 15, hour => 15, minute => 0);
$s2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 11, minute => 0);
$e2 = DateTime->new(year => 2020, month => 11, day => 15, hour => 14, minute => 0);

clear_up;

@time_recordings = ();
push @time_recordings, new_time_recording(start_time => $s1, end_time => $e1)->save;
push @time_recordings, new_time_recording(start_time => $s2, end_time => $e2);

ok( $time_recordings[1]->is_time_overlapping, 'overlapping if same staff member' );
$time_recordings[1]->update_attributes(staff_member => SL::DB::Employee->new(
                                         'login' => 'testuser',
                                         'name'  => 'Test User',
                                       )->save);
ok( !$time_recordings[1]->is_time_overlapping, 'not overlapping if different staff member' );

clear_up;

1;


# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
