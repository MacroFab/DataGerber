#!/usr/bin/env perl

use strict;
use warnings;


package Parser::Test;
use base qw(Parser::Test::Base);

use Test::More;


sub ctor : Tests()
{

    my $self = shift;

    ok(defined($self->{'parser'}), 'Validated successful creation of a Data::Gerber::Parser object.');
    ok($self->{'parser'}->isa('Data::Gerber::Parser'), 'Validated created object is an instance of Data::Gerber::Parser');
        
}

sub ctorOptions : Tests()
{

    my $self = shift;

    is($self->{'parser'}->{'ignore'}, 0, 'Validated ignore set to 0 as default.');
    is($self->{'parser'}->{'ignoreBlank'}, 0, 'Validated ignoreBlank set to 0 as default.');

    delete $self->{'parser'};

    ok(!defined($self->{'parser'}), 'Validated existing parser was deleted.');

    $self->{'parser'} = Data::Gerber::Parser->new('ignoreInvalid' => 1, 'ignoreBlank' => 1);

    ok(defined($self->{'parser'}), 'Validated recreation of a Data::Gerber object.');

    is($self->{'parser'}->{'ignore'}, 1, 'Validated ignore set to 1 when passed as option to ctor.');
    is($self->{'parser'}->{'ignoreBlank'}, 1, 'Validated ignoreBlank set to 1 when passed as option to ctor.');

}

sub errors : Tests()
{

    my $self = shift;

    $self->{'parser'}->parse();

    ok(defined($self->{'parser'}->error()), 'Validated error generated when no parsing data provided.');

}

1;
