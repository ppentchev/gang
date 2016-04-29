unit class Shell::Capture;

has Int $.exitcode;
has Str @.lines;

method capture(*@cmd) returns Shell::Capture:D
{
	my Proc:D $p = run @cmd, :out;
	my Str:D @res = $p.out.lines;
	my $exit = $p.out.close;
	return Shell::Capture.new(:exitcode($p.exitcode), :lines(@res));
}

method capture-check(List :$accept = (0,), Str :$message, *@cmd) returns Shell::Capture:D
{
	my Shell::Capture:D $r = self.capture(|@cmd);
	if not $r.exitcode (elem) $accept {
		note $message // '"' ~ @cmd ~ '" failed';
		exit 1
	}
	return $r;
}
