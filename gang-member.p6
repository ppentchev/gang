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

use GANG::Member;

my Bool $debug;

sub version()
{
	say 'gang-member 0.1.0.dev490';
}

sub USAGE(Bool:D $err = True)
{
	my $s = q:to/EOUSAGE/;
Usage:	gang-member find-git-files path
	gang-member -V | -h

	-h	display program usage information and exit
	-V	display program version information and exit
EOUSAGE

	if $err {
		$*ERR.print($s);
		exit 1;
	} else {
		print $s;
	}
}

sub note-fatal(Str:D $s)
{
	note $s;
	exit 1;
}

sub debug(Str:D $s)
{
	note $s if $debug;
}

multi sub MAIN(Bool :$h, Bool :$V)
{
	USAGE unless $h || $V;
	version if $V;
	USAGE False if $h;
}

multi sub MAIN('find-git-files', Str:D $path)
{
	say ($_.is-dir?? 'd'!! 'f') ~ " $path/" ~ $_.name for
	    GANG::Member.new(:$path).find-git-files;
}
