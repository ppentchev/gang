unit module GANG::Test::Lib;

use GANG::Lib;

sub run-check(Str:D $path, Str:D $back, *@cmd) is export returns Bool:D
{
	my Bool:D $res = True;

	sub fail(Shell::Capture:D $c, *@cmd)
	{
		note "'" ~ @cmd ~ "' failed in $path";
		chdir $back;
		$res = False;
	}

	Shell::Capture.capture-check(:&fail, |@cmd);
	return $res;
}

sub setup-site() is export returns Bool:D
{
	return False unless run-check '.', '.', 'rm', '-rf', 'vhosts';
	mkdir 'vhosts';
	mkdir 'vhosts/stuff';
	chdir 'vhosts/stuff';

	'foo.txt'.IO.spurt("This is a test.\n");
	'ignored.txt'.IO.spurt("Please ignore this...\n");
	'weird "file".txt'.IO.spurt("Please ignore this, too...\n");
	'.git-foo.txt'.IO.spurt("Is this the real life?  Is it just fantasy?\n");

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
	'ignored.txt'.IO.spurt("Please ignore this...\n");
	'weird "file".txt'.IO.spurt("Please do not ignore this...\n");

	mkdir 'another-repo';
	chdir 'another-repo';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'init';
	'hell.txt'.IO.spurt("Good intentions, eh?\n");
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'add', 'hell.txt';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'commit', '-m', 'Another first!';

	chdir '../../../..';
	return True;
}

sub modify-backup-dir() is export returns Bool:D
{
	'stuff/foo.txt'.IO.unlink;
	'stuff/what is this.txt'.IO.spurt("What is this file?\n");
	'gang-stuff/stage'.IO.spurt('hmm');
	return True;
}

sub modify-origin-site() is export returns Bool:D
{
	chdir 'vhosts/stuff';
	'foo.txt'.IO.spurt("This is only a test\n");

	chdir 'repo';
	'bar.txt'.IO.spurt("Still only a test\n");
	'baz "zzz".txt'.IO.spurt("Here's a new one!\n");
	return False unless run-check 'vhosts/stuff/repo', '../../..', 'git', 'add', 'bar.txt', 'baz "zzz".txt';
	return False unless run-check 'vhosts/stuff/repo', '../../..', 'git', 'commit', '-m', 'still';

	chdir '../more/another-repo';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'rm', 'hell.txt';
	return False unless run-check 'vhosts/stuff/more/another-repo', '../../../..', 'git', 'commit', '-m', 'begone';

	'../yet-another-repo'.IO.mkdir;
	chdir '../yet-another-repo';
	'had-enough.txt'.IO.spurt("Sigh, what now?\n");
	return False unless run-check 'vhosts/stuff/more/yet-another-repo', '../../../..', 'git', 'init';
	return False unless run-check 'vhosts/stuff/more/yet-another-repo', '../../../..', 'git', 'add', 'had-enough.txt';
	return False unless run-check 'vhosts/stuff/more/yet-another-repo', '../../../..', 'git', 'commit', '-m', 'Still here?';

	chdir '../../../..';
	return True;
}
