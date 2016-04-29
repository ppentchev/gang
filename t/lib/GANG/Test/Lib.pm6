unit module GANG::Test::Lib;

use GANG::Lib;

sub run-check(Str:D $path, Str:D $back, *@cmd) is export returns Bool:D
{
	my Shell::Capture $r .= capture(|@cmd);
	if $r.exitcode != 0 {
		note-fatal "'" ~ @cmd ~ "' failed in $path";
		chdir $back;
		return False;
	}
	return True;
}

sub setup-site() is export returns Bool:D
{
	return False unless run-check '.', '.', 'rm', '-rf', 'vhosts';
	mkdir 'vhosts';
	mkdir 'vhosts/stuff';
	chdir 'vhosts/stuff';

	'foo.txt'.IO.spurt("This is a test.\n");

	mkdir 'repo';
	chdir 'repo';
	return False unless run-check 'vhosts/stuff/repo', '../../..', 'git', 'init';
	'bar.txt'.IO.spurt("This is only a test.\n");
	return False unless run-check 'vhosts/stuff/repo', '../../..', 'git', 'add', 'bar.txt';
	return False unless run-check 'vhosts/stuff/repo', '../../..', 'git', 'commit', '-m', 'First!';

	chdir '..';
	mkdir 'more';
	chdir 'more';
	'whee.txt'.IO.spurt("Hello, Dolly!\n");

	mkdir 'another-repo';
	chdir 'another-repo';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'init';
	'hell.txt'.IO.spurt("Good intentions, eh?\n");
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'add', 'hell.txt';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'commit', '-m', 'Another first!';

	chdir '../../../..';
	return True;
}

sub modify-origin-site() is export returns Bool:D
{
	chdir 'vhosts/stuff';
	'foo.txt'.IO.spurt("This is only a test\n");

	chdir 'repo';
	'bar.txt'.IO.spurt("Still only a test\n");
	'baz.txt'.IO.spurt("Here's a new one!\n");
	return False unless run-check 'vhosts/stuff/repo', '../../..', 'git', 'add', 'bar.txt', 'baz.txt';
	return False unless run-check 'vhosts/stuff/repo', '../../..', 'git', 'commit', '-m', 'still';

	chdir '../more/another-repo';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'rm', 'hell.txt';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'commit', '-m', 'begone';

	chdir '../../../..';
	return True;
}
