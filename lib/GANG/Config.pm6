use v6.c;

use Serialize::Naive;

unit class GANG::Config does Serialize::Naive;

has Str:D $.path is required;
has Str $.remote is required;
has Str:D $.origin is required;

has UInt:D $.generation is required;
has Str:D $.tstamp is required;
