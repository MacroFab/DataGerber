#!/usr/bin/env perl

use strict;
use warnings;


use Test::Class::Load qw(t/lib);

sub main
{

    Test::Class->runtests();

    return 0;

}

exit(main());
