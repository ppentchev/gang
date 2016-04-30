#!/usr/bin/env perl6

use v6.c;

use Serialize::Naive;

use lib 'lib';
use lib 't/lib';

use GANG::Lib;
use GANG::Test::Lib;

use Test;

plan 31;

ok setup-site, 'The test site was set up properly';

ok run-check('.', '.', 'rm', '-rf', 'stuff'), 'The copy of the test site was cleaned up';
mkdir 'stuff';
ok run-check('.', '.', 'rsync', '-a', '--delete', 'vhosts/stuff/', 'stuff/'), 'The copy of the test site was created';
ok 'stuff/foo.txt'.IO.f, 'The copy of the test site contains a test file';

ok run-check('.', '.', 'rm', '-rf', 'gang-stuff'), 'The GANG copy of the test site was cleaned up';
ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', '-l', '-p=vhosts/stuff', 'init', 'stuff'), 'The GANG backup was created';
my Str:D $s = 'gang-stuff/format'.IO.slurp;
is $s, "1.0\n", 'The GANG backup has the correct "format" file.';
ok !'gang-stuff/stage'.IO.e, 'The GANG stage lockfile was removed';

ok 'stuff/.git'.IO.d, 'The GANG backup has a Git repository';
ok !'stuff/repo/.git'.IO.d, 'The GANG backup does not have the Git repository from the site';
ok 'gang-stuff/git/repo/.git'.IO.d, 'The GANG backup moved a Git repository';

chdir 'stuff';
my Shell::Capture:D $r .= capture('env', 'LANG=C', 'git', 'status', '--short');
is $r.exitcode, 0, 'stuff: git status --short succeeded';
is $r.lines.elems, 0, 'stuff: git status --short output nothing';

chdir '../gang-stuff/git/repo';
$r .= capture('env', 'LANG=C', 'git', 'status', '--short');
is $r.exitcode, 0, 'gang/git/repo: git status --short succeeded';
is $r.lines.elems, 1, 'gang/git/repo: git status --short output a single line';
is $r.lines[0], ' D bar.txt', 'gang/git/repo: git status --short complained about the missing bar.txt';

chdir '../../..';
ok !'gang-stuff/git-removed'.IO.d, 'The git-removed GANG directory is not present yet';

ok modify-origin-site, 'The origin site was modified';

ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'sync-not-git', 'stuff'), 'The GANG backup was updated for the non-Git files';
ok !'stuff/more/another-repo/hell.txt'.IO.e, 'The hell.txt file was removed';
is 'stuff/foo.txt'.IO.slurp, "This is only a test\n", 'The foo.txt file was updated';
is 'stuff/repo/bar.txt'.IO.slurp, "Still only a test\n", 'The bar.txt file was updated';

chdir 'stuff';
$r .= capture('env', 'LANG=C', 'git', 'status', '--short');
is $r.exitcode, 0, 'stuff: git status --short succeeded';
is $r.lines.elems, 0, 'stuff: git status --short output nothing';

chdir '..';

# Right, now let's remove some of the stuff
ok run-check('.', '.', 'rm', '-rf', 'vhosts/stuff/repo/.git'), 'A test repository was removed';
ok run-check('.', '.', 'perl6', '-I', 'lib', 'gang-boss.p6', 'sync-git', 'stuff'), 'The GANG backup was updated for the Git files';
ok !'gang-stuff/git/repo/.git'.IO.d, 'The corresponding GANG repository was removed, too';
ok 'gang-stuff/git/more/yet-another-repo/.git'.IO.d, 'The new GANG repository was added';

my IO::Path:D @rm = 'gang-stuff/git-removed'.IO.dir;
is @rm.elems, 1, 'The git-removed GANG directory was created with a single record';
my IO::Path:D $base = @rm[0];
ok $base.starts-with('gang-stuff/git-removed/002-'), 'The new record was created in generation 2';
ok $base.child('repo/.git').d, 'The removed repository was backed up';
