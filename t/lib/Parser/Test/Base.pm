#!/usr/bin/env perl

use strict;
use warnings;


package Parser::Test::Base;
use base qw(Test::Class);

use Test::More;
use Data::Gerber::Parser;


sub setup : Test(setup)
{

    my $self = shift;

    $self->{'parser'} = Data::Gerber::Parser->new();

}

sub teardown : Test(teardown)
{

    my $self = shift;

    delete $self->{'parser'};

}

1;
