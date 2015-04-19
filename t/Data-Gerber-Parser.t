# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Data-Gerber.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 9;
BEGIN { use_ok('Data::Gerber::Parser') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $gerbP = Data::Gerber::Parser->new();
my @testData = (
	"G04 Beginning of the file*\n",
	"%FSLAX25Y25*%\n",
	"%MOIN*%\n",
	"%LPD*%\n",
	"%ADD10C,0.000070*%\n",
	"D10*\n",
	"X123500Y001250D02*\n"
);

my @testData2 = (
	"G04 Beginning of the file*\n",
	"%FSLAX25Y25*%\n",
	"%MOIN*%\n",
	"%LPD*%\n",
	"%ADD10C,0.000070*%\n",
	"D10*\n",
	"X103500Y001250D02*\n",
	"X020000*\n"
);

my @testData3 = (
	"G04 Beginning of the file*\n",
	"%FSLAX25Y25*%\n",
	"%MOIN*%\n",
	"%LPD*%\n",
	"%ADD10C,0.000070*%\n",
	"D10*\n",
	"X103500Y001250*\n",
);

ok( defined($gerbP), "new()");
ok( $gerbP->isa('Data::Gerber::Parser'), "class");

my $gerb = $gerbP->parse(\@testData);

ok( defined($gerb), 'Returned Object');

is( $gerb->functions( 'count' => 1 ), 4, 'Function Count');
is( $gerb->mode(), 'IN', 'Correct Mode');

ok( checkFormat($gerb), 'Read Format');

$gerb = $gerbP->parse(\@testData2);

ok( defined($gerb), 'Returned Object with Continuing DCode');

$gerb = $gerbP->parse(\@testData3);

ok( ! defined($gerb), 'Fail with no defined DCode');

sub checkFormat {

 my $gerb = shift;
 my  $fmt = $gerb->format();
 
 if( $fmt->{'zero'} ne 'L' ||
     $fmt->{'coordinates'} ne 'A' ||
     $fmt->{'format'}{'integer'} != 2 ||
     $fmt->{'format'}{'decimal'} != 5 ) {
     
     return undef;
 }
 else {
 	return 1;
 }
 
}


sub checkFunc0 {

 my $gerb = shift;
 my $func = $gerb->functions( 'num' => 0 );
 
 return undef if( ! exists( $func->{'func'} )  || $func->{'func'} ne 'G01' );
 return undef if( ! exists( $func->{'coord'} ) || $func->{'coord'} ne 'X001000Y001000' );
 return undef if( ! exists( $func->{'op'} )    || $func->{'op'} ne 'D01' );
 
 return 1;
}



