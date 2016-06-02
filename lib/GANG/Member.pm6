use v6.c;

unit class GANG::Member;

has Str:D $.path is required;
has Str $.remote;

use GANG::Git-File;
use GANG::Lib;

method find-git-files() returns Array[GANG::Git-File:D]
{
	my Shell::Capture $r;
	
	if $!remote.defined {
		$r .= capture-check(
		    'ssh', $!remote, 'gang-member', 'find-git-files', $!path,
		    :message("Could not invoke 'gang-member' on $!remote to find the Git files in $!path"));
	} else {
		$r .= capture-check(
		    'find', $!path, '-name', '.git*', '-printf', '%y %p\n', '-prune',
		    :message("Could not find the Git files in $!path"));
	}

	my UInt:D $len = $!path.chars + 1;
	my GANG::Git-File:D @res;
	for $r.lines -> Str:D $line {
		if $line !~~ /^ $<type> = ['d' || 'f'] \s+ $<name> = [.+] $/ {
			die "find $!path returned a weird result '$line'";
		}
		my ($type, $name) = ($/<type>, $/<name>);
		if $name.substr(0, $len) ne "$!path/" {
			die "find $!path returned a weird filename '$name' (compared $len chars, expected '$!path/', got '" ~ $name.substr(0, $len) ~ "'";
		}
		push @res, GANG::Git-File.new(:name($name.substr($len)), :is-dir($type eq 'd'));
	}
	return @res;
}
