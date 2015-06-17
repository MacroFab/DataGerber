#!/usr/bin/env perl

use strict;
use warnings;


package Arc::Test;
use base qw(Parser::Test::Base);

use Test::More;
use Data::Gerber::Writer;
use Data::Dumper;

sub macro : Tests()
{

    my $self = shift;
    my $testFile = './t/files/macro.test';

    my $gerber = $self->{'parser'}->parse($testFile);

    ok(defined($gerber), 'Validated Gerber macro file was parsed.');

    my $m1 = $gerber->macro('OC8');
    my $m2 = $gerber->macro('SQUAREWITHHOLE');
    my $m3 = $gerber->macro('T103');
    my $m4 = $gerber->macro('T102');

    isa_ok($m1, 'ARRAY', 'Validated macro m1 was parsed correctly.');
    isa_ok($m2, 'ARRAY', 'Validated macro m2 was parsed correctly.');
    isa_ok($m3, 'ARRAY', 'Validated macro m3 was parsed correctly.');
    isa_ok($m4, 'ARRAY', 'Validated macro m4 was parsed correctly.');

}


1;
