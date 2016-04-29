unit module GANG::Lib;

use Shell::Capture;

sub note-fatal(Str:D $s) is export
{
	note $s;
	exit 1;
}
