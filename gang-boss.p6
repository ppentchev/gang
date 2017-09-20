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

use JSON::Fast;
use Shell::Capture;

use GANG::Config;
use GANG::Lib;
use GANG::Member;

my Bool $debug;
my Str $tstamp;
our $VERSION = '0.1.0.dev491';

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
Usage:	gang-boss [-v] [--exclude=rsync-exclude-spec] --remote=user@host --origin=remotepath init path
	gang-boss [-v] [--exclude=rsync-exclude-spec] --origin=localpath init path
	gang-boss [-v] sync-not-git path
	gang-boss [-v] sync-git path
	gang-boss [-v] clean-up path
	gang-boss -V | -h

	--exclude	specify a pattern to be excluded when rsync'ing
			(may be specified more than once)
	-h		display program usage information and exit
	--origin	FIXME meow
	--remote	FIXME meow
	-V		display program version information and exit
	-v		verbose operation; display diagnostic output

Commands:
	init		initialize GANG backup tracking for the specified origin
			location from a local copy at the specified path
	sync-not-git	FIXME meow
	sync-git	FIXME meow
	clean-up	attempt to clean the backup directory up if another
			command failed for some reason

Suggested use:
	rsync -a --delete --exclude=/logs --exclude=.well-known u@h:rpath/ path/
	gang-boss --remote u@h --origin rpath --exclude=/logs --exclude=.well-known init path

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

sub gang-load-config(IO::Path:D $gang-path, Str:D $path, Bool :$ignore-stage) returns GANG::Config:D
{
	my Str:D $fmt = $gang-path.child('format').slurp;
	if $fmt ne "1.0\n" {
		note-fatal "Unrecognized GANG backup format '$fmt.chomp()'";
	}
	if $gang-path.child('stage').e && !$ignore-stage {
		note-fatal "A GANG operation is in progress on $path: " ~ $gang-path.child('stage').slurp.chomp;
	}

	return GANG::Config.deserialize(
	    from-json $gang-path.child('meta.json').slurp);
}

sub git-clean-up(Str:D :$path, Str:D :$cwd)
{
	debug "Resetting the files in $path to our last Git state, just in case";
	chdir $path;
	my Shell::Capture $r .= capture-check('git', 'reset', '--hard');
	$r .= capture-check('git', 'status', '--short', '-z', :nl("\0"));
	my Str:D @extra;
	for $r.lines -> Str:D $line {
		if $line !~~ /^ '??' \s+ $<path> = [ .* ] $$ / {
			note-fatal "git status --short in $path returned an unexpected line: $line";
		}
		push @extra, ~$/<path>;
	}
	$r.capture-check('rm', '-rf', '--', $_) for @extra;
	$r .= capture-check('git', 'status', '--short', '-z', :nl("\0"));
	if $r.lines {
		note-fatal "Could not clean up $path completely";
	}
	chdir $cwd;
}

sub do-init(Str:D :$path, Str :$remote, Str:D :$origin, :@exclude)
{
	my IO::Path:D $gang-dir = $path.IO.parent.child("gang-" ~ $path.IO.basename);
	my Str:D $gang-abs = $gang-dir.absolute;
	note-fatal "The GANG directory $gang-dir already exists" if $gang-dir.e;
	debug "Creating the GANG directory $gang-dir";
	$gang-dir.mkdir;
	
	my GANG::Config $cfg .= new(
		:$path,
		:$remote,
		:$origin,
		:generation(0),
		:$tstamp,
		:@exclude,
	);

	$gang-dir.child('stage').spurt("init\n");
	$gang-dir.child('format').spurt("1.0\n");
	$gang-dir.child('meta.json').spurt(to-json($cfg.serialize) ~ "\n");

	# OK, now let's find all the Git files and move them out of the way
	debug "Looking for Git repositories and config files in $path";
	$gang-dir.child('git').mkdir;
	my GANG::Member $memb .= new(:path($path));
	my Str:D @git-files = $memb.find-git-files.map(*.name);
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

subset File-Dir of Str:D where *.IO.d;
subset File-Non-Dir of Str:D where !*.IO.d;

multi sub MAIN(Bool :$h, Bool :$V)
{
	USAGE unless $h || $V;
	version if $V;
	USAGE False if $h;
}

multi sub MAIN('init', File-Dir $path, Bool :$v, Str:D :$remote, Str:D :$origin, :@exclude)
{
	$debug = $v;
	tstamp-init;

	do-init :$path, :$remote, :$origin, :@exclude;
}

multi sub MAIN('init', File-Dir $path, Bool :$v, File-Dir :$origin, :@exclude)
{
	$debug = $v;
	tstamp-init;

	do-init :$path, :remote(Str), :$origin, :@exclude;
}

multi sub MAIN('init', File-Dir $path, Bool :$v, File-Non-Dir :$origin)
{
	note-fatal "The local origin directory '$origin' does not exist";
}

multi sub MAIN('init', File-Non-Dir $path, Bool :$v, Str :$remote, Str:D :$origin)
{
	note-fatal "The local mirror directory '$path' does not exist";
}

multi sub MAIN('sync-not-git', File-Dir $path, Bool :$v)
{
	$debug = $v;
	tstamp-init;

	my Str:D $cwd = '.'.IO.absolute;
	my Str:D $path-abs = $path.IO.absolute;
	my IO::Path:D $gang-path = "gang-$path".IO;
	my Str:D $gang-abs = $gang-path.absolute;

	my GANG::Config:D $cfg = gang-load-config $gang-path, $path;
	$gang-path.child('stage').spurt('sync-not-git');
	$cfg .= bump($tstamp);

	# First let's make sure our copy is at least hopefully good
	git-clean-up :path($path), :cwd($cwd);

	# OK, let's try to sync the stuff
	my Str:D $source-prefix = $cfg.remote.defined?? $cfg.remote ~ ':'!! '';
	my Str:D $source = $source-prefix ~ $cfg.origin ~ '/';
	debug "Synching $source to $path/";
	my Shell::Capture $r .= capture-check('rsync', '-az', '--delete',
	    '--exclude', '.git*',
	    |$cfg.exclude.map('--exclude=' ~ *),
	    $source, "$path/");
	debug "- got $r.lines().elems() lines of rsync output";

	debug "Let's see what has changed now";
	chdir $path;
	$r .= capture-check('git', 'status', '--short', '-z', :nl("\0"));
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
		sub git-xargs(Str:D $subcmd)
		{
			my Proc:D $xargs = run 'xargs', '-0', 'git', $subcmd, '--', :in, :out;

			$xargs.in.print("$_\0") for |%changed{$subcmd};
			my Proc $iproc = $xargs.in.close;
			my Int:D $ires = $iproc.defined
				?? $iproc.exitcode
				!! 0;

			my $ignored = $xargs.out.lines;
			my Proc:D $oproc = $xargs.out.close;
			my Int:D $ores = $oproc.exitcode;

			my Int:D $res = $ires || $ores;
			note-fatal "Could not update the non-Git files: 'xargs git $subcmd' exited with code $res"
			    unless $res == 0;
		}

		debug "%changed<add>.elems() file(s) to add, %changed<rm>.elems() file(s) to remove";
		git-xargs 'add' if %changed<add>;
		git-xargs 'rm' if %changed<rm>;
		$r .= capture-check('git', 'commit', '-m', "GANG: recording changes for $tstamp");
	} else {
		debug "Nothing changed in $path";
	}
	chdir $cwd;

	$gang-path.child('meta.json').spurt(to-json($cfg.serialize) ~ "\n");
	$gang-abs.IO.child('stage').unlink;
}

multi sub MAIN('sync-not-git', File-Non-Dir $path, Bool :$v)
{
	note-fatal "The local mirror directory '$path' does not exist";
}

multi sub MAIN('sync-git', File-Dir $path, Bool :$v)
{
	$debug = $v;
	tstamp-init;

	my Str:D $cwd = '.'.IO.absolute;
	my Str:D $path-abs = $path.IO.absolute;
	my IO::Path:D $gang-path = "gang-$path".IO;
	my Str:D $gang-abs = $gang-path.absolute;

	my GANG::Config:D $cfg = gang-load-config $gang-path, $path;
	$gang-path.child('stage').spurt('sync-git');
	$cfg .= bump($tstamp);

	# OK, figure out what's the state of the Git repositories
	my GANG::Git-File:D @current-git-files = GANG::Member.new(
	    :path(~$gang-path.child('git')))
	    .find-git-files;
	my GANG::Git-File:D @new-git-files = GANG::Member.new(
	    :path($cfg.origin),
	    :remote($cfg.remote))
	    .find-git-files;
	debug "Got @current-git-files.elems() stored Git-related files, @new-git-files.elems() at the new site";

	# Remove the ones that are no longer relevant
	my Set $removed = Set(@current-git-files.map(*.name)) ∖ Set(@new-git-files.map(*.name));
	if $removed {
		debug "- removing $removed.elems() Git-related files";
		my IO::Path:D $src = $gang-path.child('git');
		my IO::Path:D $dst = $gang-path.child(
		    sprintf('git-removed/%03d-%s', $cfg.generation, $cfg.tstamp))
		    .IO;
		for $removed.keys -> Str:D $git-path {
			debug "  - $git-path";
			$dst.child($git-path).parent.mkdir;
			$src.child($git-path).rename($dst.child($git-path));
		}
	} else {
		debug 'No Git files or directories to remove';
	}

	# Now sync the new ones
	debug "Synching Git files and repositories";
	my IO::Path:D $src = $cfg.origin.IO;
	my IO::Path:D $dst = $gang-path.child('git');
	for @new-git-files -> GANG::Git-File:D $git-path {
		my Str:D $dir-suffix = $git-path.is-dir?? '/'!! '';
		debug "- $git-path.name(): suffix '$dir-suffix'";
		my Str:D $source-prefix = $cfg.remote.defined?? $cfg.remote ~ ':'!! '';
		my Str:D @cmd = ('rsync', '-az', '--delete',
		    $source-prefix ~ $src.child($git-path.name) ~ $dir-suffix,
		    $dst.child($git-path.name) ~ $dir-suffix);
		$dst.child($git-path.name).parent.mkdir;
		my Shell::Capture $r .= capture-check(
		    :message("Could not sync the $git-path.name() Git artifact"),
		    |@cmd);
	}

	$gang-path.child('meta.json').spurt(to-json($cfg.serialize) ~ "\n");
	$gang-abs.IO.child('stage').unlink;
}

multi sub MAIN('sync-git', File-Non-Dir $path, Bool :$v)
{
	note-fatal "The local mirror directory '$path' does not exist";
}

multi sub MAIN('clean-up', Str $path, Bool :$v)
{
	$debug = $v;
	tstamp-init;

	my Str:D $cwd = '.'.IO.absolute;
	my Str:D $path-abs = $path.IO.absolute;
	my IO::Path:D $gang-path = "gang-$path".IO;
	my Str:D $gang-abs = $gang-path.absolute;

	my GANG::Config:D $cfg = gang-load-config $gang-path, $path, :ignore-stage;
	$gang-path.child('stage').spurt('clean-up');

	debug "Cleaning up in $path";
	git-clean-up :path($path), :cwd($cwd);

	$gang-path.child('stage').unlink;
}
