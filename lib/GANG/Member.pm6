use v6.c;

unit class GANG::Member;

has Str:D $.path is required;

use GANG::Lib;

method find-git-files() returns Array[Str:D]
{
	my GANG::Command-Output:D $r .= capture(
	    'find', $!path, '-name', '.git*', '-print', '-prune');
	if $r.exitcode != 0 {
		die "Could not find the Git files in " ~ $!path;
	}

	my UInt:D $len = $!path.chars + 1;
	my Str:D @res;
	for $r.lines -> Str:D $line {
		if $line.substr(0, $len) ne "$!path/" {
			die "find $!path returned a weird result '$line' (compared $len chars, expected '$!path/', got '" ~ $line.substr(0, $len) ~ "'";
		}
		push @res, $line.substr($len);
	}
	return @res;
}
