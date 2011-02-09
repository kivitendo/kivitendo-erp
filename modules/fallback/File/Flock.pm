# Copyright (C) 1996, 1998 David Muir Sharnoff

package File::Flock;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(lock unlock lock_rename);

use Carp;
use POSIX qw(EAGAIN EACCES EWOULDBLOCK ENOENT EEXIST O_EXCL O_CREAT O_RDWR); 
use Fcntl qw(LOCK_SH LOCK_EX LOCK_NB LOCK_UN);
use IO::File;

use vars qw($VERSION $debug $av0debug);

BEGIN	{
	$VERSION = 2008.01;
	$debug = 0;
	$av0debug = 0;
}

use strict;
no strict qw(refs);

my %locks;		# did we create the file?
my %lockHandle;
my %shared;
my %pid;
my %rm;

sub new
{
	my ($pkg, $file, $shared, $nonblocking) = @_;
	&lock($file, $shared, $nonblocking) or return undef;
	return bless \$file, $pkg;
}

sub DESTROY
{
	my ($this) = @_;
	unlock($$this);
}

sub lock
{
	my ($file, $shared, $nonblocking) = @_;

	my $f = new IO::File;

	my $created = 0;
	my $previous = exists $locks{$file};

	# the file may be springing in and out of existance...
	OPEN:
	for(;;) {
		if (-e $file) {
			unless (sysopen($f, $file, O_RDWR)) {
				redo OPEN if $! == ENOENT;
				croak "open $file: $!";
			}
		} else {
			unless (sysopen($f, $file, O_CREAT|O_EXCL|O_RDWR)) {
				redo OPEN if $! == EEXIST;
				croak "open >$file: $!";
			}
			print STDERR " {$$ " if $debug; # }
			$created = 1;
		}
		last;
	}
	$locks{$file} = $created || $locks{$file} || 0;
	$shared{$file} = $shared;
	$pid{$file} = $$;
	
	$lockHandle{$file} = $f;

	my $flags;

	$flags = $shared ? LOCK_SH : LOCK_EX;
	$flags |= LOCK_NB
		if $nonblocking;
	
	local($0) = "$0 - locking $file" if $av0debug && ! $nonblocking;
	my $r = flock($f, $flags);

	print STDERR " ($$ " if $debug and $r;

	if ($r) {
		# let's check to make sure the file wasn't
		# removed on us!

		my $ifile = (stat($file))[1];
		my $ihandle;
		eval { $ihandle = (stat($f))[1] };
		croak $@ if $@;

		return 1 if defined $ifile 
			and defined $ihandle 
			and $ifile == $ihandle;

		# oh well, try again
		flock($f, LOCK_UN);
		close($f);
		return File::Flock::lock($file);
	}

	return 1 if $r;
	if ($nonblocking and 
		(($! == EAGAIN) 
		or ($! == EACCES)
		or ($! == EWOULDBLOCK))) 
	{
		if (! $previous) {
			delete $locks{$file};
			delete $lockHandle{$file};
			delete $shared{$file};
			delete $pid{$file};
		}
		if ($created) {
			# oops, a bad thing just happened.  
			# We don't want to block, but we made the file.
			&background_remove($f, $file);
		}
		close($f);
		return 0;
	}
	croak "flock $f $flags: $!";
}

#
# get a lock on a file and remove it if it's empty.  This is to
# remove files that were created just so that they could be locked.
#
# To do this without blocking, defer any files that are locked to the
# the END block.
#
sub background_remove
{
	my ($f, $file) = @_;

	if (flock($f, LOCK_EX|LOCK_NB)) {
		unlink($file)
			if -s $file == 0;
		flock($f, LOCK_UN);
		return 1;
	} else {
		$rm{$file} = 1
			unless exists $rm{$file};
		return 0;
	}
}

sub unlock
{
	my ($file) = @_;

	if (ref $file eq 'File::Flock') {
		bless $file, 'UNIVERSAL'; # avoid destructor later
		$file = $$file;
	}

	croak "no lock on $file" unless exists $locks{$file};
	my $created = $locks{$file};
	my $unlocked = 0;


	my $size = -s $file;
	if ($created && defined($size) && $size == 0) {
		if ($shared{$file}) {
			$unlocked = 
				&background_remove($lockHandle{$file}, $file);
		} else { 
			# {
			print STDERR " $$} " if $debug;
			unlink($file) 
				or croak "unlink $file: $!";
		}
	}
	delete $locks{$file};
	delete $pid{$file};

	my $f = $lockHandle{$file};

	delete $lockHandle{$file};

	return 0 unless defined $f;

	print STDERR " $$) " if $debug;
	$unlocked or flock($f, LOCK_UN)
		or croak "flock $file UN: $!";

	close($f);
	return 1;
}

sub lock_rename
{
	my ($oldfile, $newfile) = @_;

	if (exists $locks{$newfile}) {
		unlock $newfile;
	}
	delete $locks{$newfile};
	delete $shared{$newfile};
	delete $pid{$newfile};
	delete $lockHandle{$newfile};
	delete $rm{$newfile};

	$locks{$newfile}	= $locks{$oldfile}	if exists $locks{$oldfile};
	$shared{$newfile}	= $shared{$oldfile}	if exists $shared{$oldfile};
	$pid{$newfile}		= $pid{$oldfile}	if exists $pid{$oldfile};
	$lockHandle{$newfile}	= $lockHandle{$oldfile} if exists $lockHandle{$oldfile};
	$rm{$newfile}		= $rm{$oldfile}		if exists $rm{$oldfile};

	delete $locks{$oldfile};
	delete $shared{$oldfile};
	delete $pid{$oldfile};
	delete $lockHandle{$oldfile};
	delete $rm{$oldfile};
}

#
# Unlock any files that are still locked and remove any files
# that were created just so that they could be locked.
#
END {
	my $f;
	for $f (keys %locks) {
		&unlock($f)
			if $pid{$f} == $$;
	}

	my %bgrm;
	for my $file (keys %rm) {
		my $f = new IO::File;
		if (sysopen($f, $file, O_RDWR)) {
			if (flock($f, LOCK_EX|LOCK_NB)) {
				unlink($file)
					if -s $file == 0;
				flock($f, LOCK_UN);
			} else {
				$bgrm{$file} = 1;
			}
			close($f);
		}
	}
	if (%bgrm) {
		my $ppid = fork;
		croak "cannot fork" unless defined $ppid;
		my $pppid = $$;
		my $b0 = $0;
		$0 = "$b0: waiting for child ($ppid) to fork()";
		unless ($ppid) {
			my $pid = fork;
			croak "cannot fork" unless defined $pid;
			unless ($pid) {
				for my $file (keys %bgrm) {
					my $f = new IO::File;
					if (sysopen($f, $file, O_RDWR)) {
						if (flock($f, LOCK_EX)) {
							unlink($file)
								if -s $file == 0;
							flock($f, LOCK_UN);
						}
						close($f);
					}
				}
				print STDERR " $pppid] $pppid)" if $debug;
			}
			kill(9, $$); # exit w/o END or anything else
		}
		waitpid($ppid, 0);
		kill(9, $$); # exit w/o END or anything else
	}
}

1;

__DATA__

=head1 NAME

 File::Flock - file locking with flock

=head1 SYNOPSIS

 use File::Flock;

 lock($filename);

 lock($filename, 'shared');

 lock($filename, undef, 'nonblocking');

 lock($filename, 'shared', 'nonblocking');

 unlock($filename);

 my $lock = new File::Flock '/somefile';

 lock_rename($oldfilename, $newfilename)

=head1 DESCRIPTION

Lock files using the flock() call.  If the file to be locked does not
exist, then the file is created.  If the file was created then it will
be removed when it is unlocked assuming it's still an empty file.

Locks can be created by new'ing a B<File::Flock> object.  Such locks
are automatically removed when the object goes out of scope.  The
B<unlock()> method may also be used.

B<lock_rename()> is used to tell File::Flock when a file has been
renamed (and thus the internal locking data that is stored based
on the filename should be moved to a new name).  B<unlock()> the
new name rather than the original name.

=head1 LICENSE

File::Flock may be used/modified/distibuted on the same terms
as perl itself.  

=head1 AUTHOR

David Muir Sharnoff <muir@idiom.org>


