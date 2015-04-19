# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Data-Gerber.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 7;

use Data::Gerber::Parser;

BEGIN { use_ok('Data::Gerber::Writer') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $gerbP = Data::Gerber::Parser->new();
my $gerbW = Data::Gerber::Writer->new();

my @testData = (
	"%FSLAX25Y25*\%\n",
	"%MOIN*\%\n",
	"%AMODD*\n",
	"1,1,$1,0,0*\n",
	"1,0,$1-0.005,0,0*\%\n",
	"\%ADD10C,0.000070*\%\n",
	"\%LPD*\%\n",
	"D10*\n",
	"X123500Y001250D02*\n",
	"M02*\n"
);

my $matchStr = join('', @testData);


ok( defined($gerbW), "new()");
ok( $gerbW->isa('Data::Gerber::Writer'), "class");

my $gerb = $gerbP->parse(\@testData);

ok( defined($gerb), 'Gerber Parser Returned Object');


my($newContent, $handle);
ok( open( $handle, '>', \$newContent ), 'In-Memory File Handle');

my $ret = $gerbW->write($handle, $gerb);

ok( defined($ret), 'Writer returns true ' . $gerbW->error() );

close($handle);

cmp_ok($newContent, 'eq', $matchStr, 'Re-Constructed Object');


