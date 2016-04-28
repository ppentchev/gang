unit class GANG::Command-Output;

has Int $.exitcode;
has Str @.lines;

method capture(*@cmd) returns GANG::Command-Output:D
{
	my Proc:D $p = run @cmd, :out;
	my Str:D @res = $p.out.lines;
	my $exit = $p.out.close;
	return GANG::Command-Output.new(:exitcode($p.exitcode), :lines(@res));
}

method capture-check(*@cmd) returns GANG::Command-Output:D
{
	my GANG::Command-Output:D $r = self.capture(|@cmd);
	if $r.exitcode != 0 {
		note "Running '" ~ @cmd ~ "' failed";
		exit 1
	}
	return $r;
}
