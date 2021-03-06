#!/usr/bin/env perl6

use v6.c;

use Serialize::Naive;
use Shell::Capture;

use lib 'lib';
use lib 't/lib';

use GANG::Lib;
use GANG::Test::Lib;

use Test;

plan 67;

my @exclude = ('ignored.txt', '/weird "file".txt').map('--exclude=' ~ *);

ok setup-site, 'The test site was set up properly';

ok run-check('.', '.', 'rm', '-rf', 'stuff'), 'The copy of the test site was cleaned up';
mkdir 'stuff';
ok run-check('.', '.', 'rsync', '-a', '--delete', 'vhosts/stuff/',
    |@exclude, 'stuff/'),
   'The copy of the test site was created';
ok 'stuff/foo.txt'.IO.f, 'The copy of the test site contains a test file';
ok !'stuff/ignored.txt'.IO.f, 'The copy of the test suite does not contain an ignored file';
ok !'stuff/more/ignored.txt'.IO.f, 'The copy of the test suite does not contain another ignored file';
ok !'stuff/weird "file".txt'.IO.f, 'The copy of the test suite does not contain the top-level weird file';
ok 'stuff/more/weird "file".txt'.IO.f, 'The copy of the test suite contains the non-top-level weird file';
ok 'stuff/.git-foo.txt'.IO.f, 'The copy of the test suite contains the Git-like file';

ok run-check('.', '.', 'rm', '-rf', 'gang-stuff'), 'The GANG copy of the test site was cleaned up';
ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', '--origin=vhosts/stuff',
    |@exclude, 'init', 'stuff'),
   'The GANG backup was created';
my Str:D $s = 'gang-stuff/format'.IO.slurp;
is $s, "1.0\n", 'The GANG backup has the correct "format" file.';
ok !'gang-stuff/stage'.IO.e, 'The GANG stage lockfile was removed';

ok 'stuff/.git'.IO.d, 'The GANG backup has a Git repository';
ok !'stuff/repo/.git'.IO.d, 'The GANG backup does not have the Git repository from the site';
ok 'gang-stuff/git/repo/.git'.IO.d, 'The GANG backup moved a Git repository';
ok !'stuff/.git-foo.txt'.IO.f, 'The GANG backup does not have the Git-like file';
ok 'gang-stuff/git/.git-foo.txt'.IO.f, 'The GANG backup moved the Git-like file';

chdir 'stuff';
my Shell::Capture:D $r .= capture('env', 'LANG=C', 'git', 'status', '--short', 'z', :nl("\0"));
is $r.exitcode, 0, 'stuff: git status --short succeeded';
is $r.lines.elems, 0, 'stuff: git status --short output nothing';

chdir '../gang-stuff/git/repo';
$r .= capture('env', 'LANG=C', 'git', 'status', '--short', '-z', :nl("\0"));
is $r.exitcode, 0, 'gang/git/repo: git status --short succeeded';
is $r.lines.elems, 1, 'gang/git/repo: git status --short output a single line';
is $r.lines[0], ' D bar.txt', 'gang/git/repo: git status --short complained about the missing bar.txt';

chdir '../../..';
ok !'gang-stuff/git-removed'.IO.d, 'The git-removed GANG directory is not present yet';

ok modify-backup-dir, 'The backup directory was modified';
ok 'gang-stuff/stage'.IO.f, 'The in-progress flag file was created';
ok 'stuff/what is this.txt'.IO.f, 'A new file was created';
ok !'stuff/foo.txt'.IO.f, 'An existing file was removed';
chdir 'stuff';
$r .= capture('env', 'LANG=C', 'git', 'status', '--short', '-z', :nl("\0"));
is $r.exitcode, 0, 'gang/git/repo: git status --short succeeded';
is $r.lines.elems, 2, 'gang/git/repo: git status --short output two lines';
chdir '..';

ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'clean-up', 'stuff'), 'The GANG backup was cleaned up';
ok !'gang-stuff/stage'.IO.f, 'The in-progress flag file was created';
ok !'stuff/what is this.txt'.IO.f, 'A new file was created';
ok 'stuff/foo.txt'.IO.f, 'An existing file was removed';
chdir 'stuff';
$r .= capture('env', 'LANG=C', 'git', 'status', '--short', '-z', :nl("\0"));
is $r.exitcode, 0, 'stuff: git status --short succeeded';
is $r.lines.elems, 0, 'stuff: git status --short output nothing';
chdir '..';

ok modify-origin-site, 'The origin site was modified';

ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'sync-not-git', 'stuff'), 'The GANG backup was updated for the non-Git files';
ok !'stuff/ignored.txt'.IO.f, 'The copy of the test suite still does not contain an ignored file';
ok !'stuff/more/ignored.txt'.IO.f, 'The copy of the test suite still does not contain another ignored file';
ok !'stuff/weird "file".txt'.IO.f, 'The copy of the test suite still does not contain the top-level weird file';
ok 'stuff/more/weird "file".txt'.IO.f, 'The copy of the test suite still contains the non-top-level weird file';
ok !'stuff/more/another-repo/hell.txt'.IO.e, 'The hell.txt file was removed';
is 'stuff/foo.txt'.IO.slurp, "This is only a test\n", 'The foo.txt file was updated';
is 'stuff/repo/bar.txt'.IO.slurp, "Still only a test\n", 'The bar.txt file was updated';

chdir 'stuff';
$r .= capture('env', 'LANG=C', 'git', 'status', '--short', '-z', :nl("\0"));
is $r.exitcode, 0, 'stuff: git status --short succeeded';
is $r.lines.elems, 0, 'stuff: git status --short output nothing';

chdir '..';

# Right, now let's remove some of the stuff
ok run-check('.', '.', 'rm', '-rf', 'vhosts/stuff/repo/.git'), 'A test repository was removed';
ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'sync-git', 'stuff'), 'The GANG backup was updated for the Git files';
ok !'gang-stuff/git/repo/.git'.IO.d, 'The corresponding GANG repository was removed, too';
ok 'gang-stuff/git/more/yet-another-repo/.git'.IO.d, 'The new GANG repository was added';

# Let us add a whole lot more stuff now
my $large = 'some-really-really-long-filenames-and-stuff-and-more-characters';
my $large_base = "vhosts/stuff/$large";
my $large_target = "stuff/$large";
mkdir $large_base;
ok $large_base.IO.d, 'The source directory for the really long filenames was created';
for 0..^10 -> UInt:D $level_0 {
	my $base_0 = "$large_base/even-more-really-really-long-stuff-and-more-characters-number-$level_0";
	mkdir $base_0;
	for 0..^10 -> UInt:D $level_1 {
		my $base_1 = "$base_0/what-you-mean-there-are-even-more-and-more-and-more-number-$level_1";
		mkdir $base_1;
		for 0..^10 -> UInt:D $level_2 {
			my $base_2 = "$base_1/what-you-mean-there-are-even-more-and-more-and-more-number-$level_2";
			mkdir $base_2;
			for 0..^10 -> UInt:D $fidx {
				my $fname = "$base_2/here-is-a-really-long-filename-maybe-$fidx.txt";
				$fname.IO.spurt("$level_0 $level_1 $level_2 $fidx");
			}
		}
	}
}
ok run-check('.', '.', 'sh', '-c', '[ "$(find -- ' ~ "'$large_base'" ~ ' -type f | wc -l)" = 10000 ]'), 'A lot of files were created';
ok !$large_target.IO.d, 'The destination directory for the really long filenames does not exist';
ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'sync-not-git', 'stuff'), 'The GANG backup was updated for the non-Git files';
ok $large_target.IO.d, 'The destination directory for the really long filenames was created';
ok run-check('.', '.', 'sh', '-c', '[ "$(find -- ' ~ "'$large_target'" ~ ' -type f | wc -l)" = 10000 ]'), 'A lot of files were backed up';

for 0..^10 -> UInt:D $level_0 {
	my $base_0 = "$large_base/even-more-really-really-long-stuff-and-more-characters-number-$level_0";
	mkdir $base_0;
	for 0..^10 -> UInt:D $level_1 {
		my $base_1 = "$base_0/what-you-mean-there-are-even-more-and-more-and-more-number-$level_1";
		mkdir $base_1;
		for 0..^10 -> UInt:D $level_2 {
			my $base_2 = "$base_1/what-you-mean-there-are-even-more-and-more-and-more-number-$level_2";
			mkdir $base_2;
			for 0..^10 -> UInt:D $fidx {
				my $fname = "$base_2/here-is-a-really-long-filename-maybe-whee-$fidx.txt";
				$fname.IO.spurt("$level_0 $level_1 $level_2 $fidx");
			}
		}
	}
}
ok run-check('.', '.', 'sh', '-c', '[ "$(find -- ' ~ "'$large_base'" ~ ' -type f | wc -l)" = 20000 ]'), 'A lot more files were created';
ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'sync-not-git', 'stuff'), 'The GANG backup was updated for the non-Git files';
ok run-check('.', '.', 'sh', '-c', '[ "$(find -- ' ~ "'$large_target'" ~ ' -type f | wc -l)" = 20000 ]'), 'A lot more files were backed up';

ok run-check('.', '.', 'find', '--', $large_base, '-type', 'f', '-name', '*-maybe-whee-*.txt', '-delete'), 'Removed a lot of files';
ok run-check('.', '.', 'sh', '-c', '[ "$(find -- ' ~ "'$large_base'" ~ ' -type f | wc -l)" = 10000 ]'), 'A lot of files were removed';
ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'sync-not-git', 'stuff'), 'The GANG backup was updated for the non-Git files';
ok run-check('.', '.', 'sh', '-c', '[ "$(find -- ' ~ "'$large_target'" ~ ' -type f | wc -l)" = 10000 ]'), 'A lot of files were removed from the backup';

my IO::Path:D @rm = 'gang-stuff/git-removed'.IO.dir;
is @rm.elems, 1, 'The git-removed GANG directory was created with a single record';
my IO::Path:D $base = @rm[0];
ok $base.starts-with('gang-stuff/git-removed/002-'), 'The new record was created in generation 2';
ok $base.child('repo/.git').d, 'The removed repository was backed up';
