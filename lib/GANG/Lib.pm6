unit module GANG::Lib;

use GANG::Command-Output;

sub note-fatal(Str:D $s) is export
{
	note $s;
	exit 1;
}
