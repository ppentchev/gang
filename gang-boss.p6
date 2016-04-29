#!/usr/bin/env perl6
#
# Copyright (c) 2016  Peter Pentchev
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

use v6;
use strict;

use JSON::Fast;

use GANG::Config;
use GANG::Lib;
use GANG::Member;

my Bool $debug;
my Str $tstamp;
our $VERSION = '0.1.0.dev478';

sub debug(Str:D $s)
{
	note $s if $debug;
}

sub version()
{
	say "gang-boss $VERSION";
}

sub USAGE(Bool:D $err = True)
{
	my Str:D $s = q:to/EOUSAGE/;
Usage:	gang-boss [-v] -r=user@host -p=origin-path init path
	gang-boss [-v] -l -p=origin-path init path
	gang-boss [-v] sync-not-git path
	gang-boss [-v] sync-git path
	gang-boss -V | -h

	-h		display program usage information and exit
	-l		FIXME meow
	-p		FIXME meow
	-u		FIXME meow
	-V		display program version information and exit
	-v		verbose operation; display diagnostic output

Commands:
	init		initialize GANG backup tracking for the specified origin
			location from a local copy at the specified path
	sync-not-git	FIXME meow
	sync-git	FIXME meow

Suggested use:
	rsync -a --delete u@h:rpath/ path/
	gang-boss -u u@h -p rpath init path

	gang-boss sync-not-git path
	gang-boss sync-git path
EOUSAGE

	if $err {
		$*ERR.print($s);
		exit 1;
	} else {
		print $s;
	}
}

sub tstamp-init()
{
	$tstamp = ~DateTime.now;
}

sub gang-load-config(IO::Path:D $gang-path, Str:D $path) returns GANG::Config:D
{
	my Str:D $fmt = $gang-path.child('format').slurp;
	if $fmt ne "1.0\n" {
		note-fatal "Unrecognized GANG backup format '$fmt.chomp()'";
	}
	if $gang-path.child('stage').e {
		note-fatal "A GANG operation is in progress on $path: " ~ $gang-path.child('stage').slurp.chomp;
	}

	return GANG::Config.deserialize(
	    from-json $gang-path.child('meta.json').slurp);
}

multi sub MAIN(Bool :$h, Bool :$V)
{
	USAGE unless $h || $V;
	version if $V;
	USAGE False if $h;
}

multi sub MAIN('init', Str $path, Bool :$v, Bool :$l, Str :$r, Str :$p)
{
	$debug = $v;
	tstamp-init;

	note-fatal "The -r and -l options are mutually exclusive" if
	    $r.defined && $l;
	note-fatal "At least one of -r and -l must be specified" unless
	    $r.defined || $l;
	note-fatal "The origin path must be specified with -p" unless
	    $p.defined;
	my Str:D $origin = $p;

	note-fatal "The local mirror directory '$path' does not exist" unless
	    $path.IO.d;

	note-fatal "The local origin directory '$p' does not exist" if
	    $l && !$p.IO.d;

	my IO::Path:D $gang-dir = $path.IO.parent.child("gang-" ~ $path.IO.basename);
	my Str:D $gang-abs = $gang-dir.abspath;
	note-fatal "The GANG directory $gang-dir already exists" if $gang-dir.e;
	debug "Creating the GANG directory $gang-dir";
	$gang-dir.mkdir;
	
	my GANG::Config $cfg .= new(
		:path($path),
		:remote($r),
		:origin($origin),
		:generation(0),
		:tstamp($tstamp),
	);

	$gang-dir.child('stage').spurt("init\n");
	$gang-dir.child('format').spurt("1.0\n");
	$gang-dir.child('meta.json').spurt(to-json($cfg.serialize) ~ "\n");

	# OK, now let's find all the Git files and move them out of the way
	debug "Looking for Git repositories and config files in $path";
	$gang-dir.child('git').mkdir;
	my GANG::Member $memb .= new(:path($path));
	my Str:D @git-files = $memb.find-git-files;
	debug "Found @git-files.elems() Git directories and/or files";
	for @git-files -> Str:D $git {
		debug "- $path/$git -> $gang-dir/git/$git";
		my Str:D $parent = $git.IO.dirname;
		$gang-dir.child("git/$parent").mkdir;
		"$path/$git".IO.rename("$gang-dir/git/$git");
	}

	# Create a Git repo and store everything in it
	debug "Creating a Git repository in $path";
	chdir $path;
	run 'git', 'init';
	run 'git', 'add', '.';
	run 'git', 'commit', '-m', 'GANG initial commit';

	$gang-abs.IO.child('stage').unlink;

	debug 'Done!';
}

multi sub MAIN('sync-not-git', Str $path, Bool :$v)
{
	$debug = $v;
	tstamp-init;

	my Str:D $cwd = '.'.IO.abspath;
	my Str:D $path-abs = $path.IO.abspath;
	my IO::Path:D $gang-path = "gang-$path".IO;
	my Str:D $gang-abs = $gang-path.abspath;

	my GANG::Config:D $cfg = gang-load-config $gang-path, $path;

	# First let's make sure our copy is at least hopefully good
	debug "Resetting the files in $path to our last Git state, just in case";
	chdir $path;
	my Shell::Capture $r .= capture-check('git', 'reset', '--hard');
	$r .= capture-check('git', 'status', '--short');
	my Str:D @extra;
	for $r.lines -> Str:D $line {
		if $line !~~ /^ '??' \s+ $<path> = [ .* ] $$ / {
			note-fatal "git status --short in $path returned an unexpected line: $line";
		}
		push @extra, ~$/<path>;
	}
	$r.capture-check('rm', '-rf', '--', $_) for @extra;
	$r .= capture-check('git', 'status', '--short');
	if $r.lines {
		note-fatal "Could not clean up $path completely";
	}
	chdir $cwd;

	# OK, let's try to sync the stuff
	my Str:D $source-prefix = $cfg.remote.defined?? $cfg.remote ~ ':'!! '';
	my Str:D $source = $source-prefix ~ $cfg.origin ~ '/';
	debug "Synching $source to $path/";
	$r .= capture-check('rsync', '-az', '--delete', '--exclude', '.git*', $source, "$path/");
	debug "- got $r.lines().elems() lines of rsync output";

	debug "Let's see what has changed now";
	chdir $path;
	$r .= capture-check('git', 'status', '--short');
	my %changed = :add([]), :rm([]);
	for $r.lines -> Str:D $line {
		my Str:D ($status, $fname) = $line.substr(0, 3), $line.substr(3);
		given $status {
			when '?? ' {
				push %changed<add>, $fname;
			};

			when ' M ' {
				push %changed<add>, $fname;
			};

			when ' D ' {
				push %changed<rm>, $fname;
			};

			default {
				note-fatal "git status --short in $path returned an unexpected line: $line";
			}
		}
	}
	if %changed<add> || %changed<rm> {
		debug "%changed<add>.elems() file(s) to add, %changed<rm>.elems() file(s) to remove";
		$r .= capture-check('git', 'add', '--', $_) for |%changed<add>;
		$r .= capture-check('git', 'rm', '--', $_) for |%changed<rm>;
		$r .= capture-check('git', 'commit', '-m', "GANG: recording changes for $tstamp");
	} else {
		debug "Nothing changed in $path";
	}
	chdir $cwd;
}

multi sub MAIN('sync-git', Str $path, Bool :$v)
{
	$debug = $v;
	tstamp-init;
	...
}
