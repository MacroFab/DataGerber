#!/usr/bin/env perl

use strict;
use warnings;


package Gerber::Test;
use base qw(Gerber::Test::Base);

use Test::More;


sub ctor : Tests()
{

    my $self = shift;

    ok(defined($self->{'gerber'}), 'Validated successful creation of a Data::Gerber object.');
    ok($self->{'gerber'}->isa('Data::Gerber'), 'Validated created object is an instance of Data::Gerber');
    is( $self->{'gerber'}->functions( 'count' => 1 ), 0, 'Validated Gerber object has no functions at ctor.');
        
}

sub mode : Tests()
{

    my $self = shift;

    ok($self->{'gerber'}->mode('MM'), 'Validated could set Gerber mode to MM.');
    is($self->{'gerber'}->mode(), 'MM', 'Validated Gerber mode was set to MM.');
    ok($self->{'gerber'}->mode('IN'), 'Validated could set Gerber mode to IN.');
    is($self->{'gerber'}->mode(), 'IN', 'Validated Gerber mode was set to IN.');
    ok(!defined($self->{'gerber'}->mode('ERROR')), 'Validated setting invalid mode returned undefined.');
    ok(defined($self->{'gerber'}->error()), 'Validated setting invalid mode generated error.');

    $self->reset();

}

sub errors : Tests()
{

    my $self = shift;

    ok(!defined($self->{'gerber'}->error()), 'Validated error was undefined.');
    $self->{'gerber'}->mode('ERROR');
    ok(defined($self->{'gerber'}->error()), 'Validated error generated.');

    $self->reset();

}

sub format : Tests()
{

    my $self = shift;

    my %format = (
        'zero' => 'L',
        'coordinates' => 'A',
        'format' => {
            'integer' => 5,
            'decimal' => 5      
        }
    );

    my %formats = (
        'zero' => [ { 'value' => 'L', 'expect' => 1 }, { 'value' => 'T', 'expect' => 1 }, { 'value' => 'ERROR', 'expect' => undef } ],
        'coordinates' => [ { 'value' => 'A', 'expect' => 1 }, { 'value' => 'I', 'expect' => 1 }, { 'value' => 'ERROR', 'expect' => undef } ],
        'format' => {
            'integer' => [ { 'value' => 5, 'expect' => 1 }, { 'value' => -1, 'expect' => undef }, { 'value' => 8, 'expect' => undef } ],
            'decimal' => [ { 'value' => 5, 'expect' => 1 }, { 'value' => -1, 'expect' => undef }, { 'value' => 8, 'expect' => undef } ]
        }
    );

    ok($self->{'gerber'}->format(%format), 'Validated Gerber format was set.');

    my $ret = $self->{'gerber'}->format();

    is($ret->{'zero'}, 'L', 'Validated zero format was L.');
    is($ret->{'coordinates'}, 'A', 'Validated coordinates format was A.');
    is($ret->{'format'}->{'integer'}, 5, 'Validated integer format was 5.');
    is($ret->{'format'}->{'decimal'}, 5, 'Validated decimal format was 5.');

    foreach my $key ( keys(%formats) ) {
        my $values = $formats{$key};

        if ( ref($values) eq 'ARRAY' ) {
            foreach my $test ( @{ $values } ) {
                my $prev = $format{$key};
                $format{$key} = $test->{'value'};
                is($self->{'gerber'}->format(%format), $test->{'expect'}, "Validated value for $key");
                $format{$key} = $prev;
            }
        }
        elsif ( ref($values) eq 'HASH' ) {
            foreach my $test ( keys(%{ $values }) ) {
                foreach my $k ( keys(%{ $format{$test} }) ) {
                    my $prev = $format{$test}->{$k};
                    $format{$test}->{$k} = $test->{$k}->{'value'};
                    is($self->{'gerber'}->format(%format), $test->{$k}->{'expect'}, "Validated value for $k");
                    $format{$test}->{$k} = $prev;
                }
            }
        }
    }

    $self->reset();

}

sub addFunction : Tests()
{

    my $self = shift;

    my %function = (
        'func' => 'G01',
        'coord' => 'X500000Y500000',
        'op' => 'D02'
    );

    ok($self->{'gerber'}->function(%function), 'Validated adding G01 function to Gerber.');
    is($self->{'gerber'}->functions('count' => 1), 1, 'Validated function count was 1.');

    my $ret = $self->{'gerber'}->functions('num' => 0);

    is($ret->{'func'}, $function{'func'}, 'Validated function was ' . $function{'func'});
    is($ret->{'coord'}, $function{'coord'}, 'Validated coordinate was ' . $function{'coord'});
    is($ret->{'op'}, $function{'op'}, 'Validated op was ' . $function{'op'});

    $self->reset();

}

sub dimensionsFunction : Tests()
{

    my $self = shift;

    my @functions = (
        {
            'func' => 'G01',
            'coord' => 'X500000Y500000',
            'op' => 'D02'
        },
        {
            'func' => 'G01',
            'coord' => 'X300000Y600000',
            'op' => 'D01'
        }
    );

    foreach my $function ( @functions ) {
        ok($self->{'gerber'}->function(%{$function}), 'Validated adding function to Gerber.');
    }

    is($self->{'gerber'}->functions('count' => 2), 2, 'Validated function count was 2.');

    is($self->{'gerber'}->width(), 2, 'Validated width was 2.');
    is($self->{'gerber'}->height(), 1, 'Validated height was 1.');

    $self->reset();

}

sub reset
{

    my $self = shift;

    my $self->{'gerber'} = Data::Gerber->new();

}



1;
