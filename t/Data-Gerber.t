# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Data-Gerber.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 16;
BEGIN { use_ok('Data::Gerber') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $gerb = Data::Gerber->new();

ok( defined($gerb), "new()");
ok( $gerb->isa('Data::Gerber'), "class");

is( $gerb->functions( 'count' => 1 ), 0, 'No Starting Functions');

ok( $gerb->mode('MM'), 'Set MM Mode');
ok( $gerb->mode('IN'), 'Set IN Mode');
is( $gerb->mode(), 'IN', 'Read Mode');

ok( $gerb->format( 'zero' => 'L', 'coordinates' => 'A', 'format' => { 'integer' => 5, 'decimal' => 5 }), 'Set Format');
ok( checkFormat(), 'Read Format');

ok( $gerb->function( 'func' => 'G01', 'coord' => 'X500000Y500000', 'op' => 'D02'), 'Add Func 0');
is( $gerb->functions( 'count' => 1 ), 1, 'Func Count 0');
ok( checkFunc0(), 'Check Func 0');

is( $gerb->convert(),1,'gerb input?');

ok( $gerb->function( 'func' => 'G01', 'coord' => 'X300000Y600000', 'op' => 'D01'), 'Add Func 2');
is( $gerb->width(), 2, 'Width');
is( $gerb->height(), 2, 'Height');



sub checkFormat {

 my $fmt = $gerb->format();
 
 if( $fmt->{'zero'} ne 'L' ||
     $fmt->{'coordinates'} ne 'A' ||
     $fmt->{'format'}{'integer'} != 5 ||
     $fmt->{'format'}{'decimal'} != 5 ) {
     
     return undef;
 }
 else {
 	return 1;
 }
 
}


sub checkFunc0 {

 my $func = $gerb->functions( 'num' => 0 );
 
 return undef if( ! exists( $func->{'func'} )  || $func->{'func'} ne 'G01' );
 return undef if( ! exists( $func->{'coord'} ) || $func->{'coord'} ne 'X500000Y500000' );
 return undef if( ! exists( $func->{'op'} )    || $func->{'op'} ne 'D02' );
 
 return 1;
}



