#!/usr/bin/env perl

use strict;
use warnings;


package Gerber::Test::Base;
use base qw(Test::Class);

use Test::More;
use Data::Gerber;


sub setup : Test(setup)
{

    my $self = shift;

    $self->{'gerber'} = Data::Gerber->new();

}

sub teardown : Test(teardown)
{

    my $self = shift;

    delete $self->{'gerber'};

}

1;
