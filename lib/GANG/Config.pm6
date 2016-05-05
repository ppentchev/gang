use v6.c;

use Serialize::Naive;

unit class GANG::Config does Serialize::Naive;

has Str:D $.path is required;
has Str $.remote is required;
has Str:D $.origin is required;

has UInt:D $.generation is required;
has Str:D $.tstamp is required;

has Str:D @.exclude;

method bump(Str:D $new-tstamp) returns GANG::Config:D
{
	return GANG::Config.new(
	    :path($!path),
	    :remote($!remote),
	    :origin($!origin),
	    :generation($!generation + 1),
	    :tstamp($new-tstamp),
	    :exclude(@!exclude),
	);
}
