#!/usr/bin/env perl

package t::then_success;

use strict;
use warnings;

use parent qw(Test::Class::Tiny);

use Test::More;
use Test::Fatal;
use Test::FailWarnings;

use Cwd;
use File::Spec;

BEGIN {
    my @path = File::Spec->splitdir( Cwd::abs_path(__FILE__) );
    splice( @path, -2, 2, 'lib' );
    push @INC, File::Spec->catdir(@path);
}

use MemoryCheck;

use Eventer;
use PromiseTest;

use Promise::ES6;

sub T0_tests {
    my $test_value = 'first';

    my @todo;

    my $eventer = Eventer->new();

    my $p = Promise::ES6->new(sub {
        my ($resolve, $reject) = @_;

        push @todo, sub {
            if ($eventer->has_happened('ready1') && !$eventer->has_happened('resolved1')) {
                is $test_value, 'first';
                $test_value = 'second';
                $resolve->('first resolve');
                $eventer->happen('resolved1');
            }
        };
    });

    my $p2 = $p->then(sub {
        my ($value) = @_;
        is $value, 'first resolve';
        is $test_value, 'second';
        $test_value = 'third';
        return 'second resolve';
    });

    my $p3 = $p2->then(sub {
        my ($value) = @_;
        is $value, 'second resolve';

        is $test_value, 'third';
        $test_value = 'fourth';

        my $p4 = Promise::ES6->new(sub {
            my ($resolve, $reject) = @_;

            push @todo, sub {
                if ($eventer->has_happened('ready2') && !$eventer->has_happened('resolved2')) {
                    is $test_value, 'fourth';
                    $test_value = 'fifth';
                    $resolve->('third resolve');
                    $eventer->happen('resolved2');
                }
            };
        });

        return $p4;
    });

    my $pid = fork or do {
        Time::HiRes::sleep(0.2);

        $eventer->happen('ready1');

        Time::HiRes::sleep(0.2);

        $eventer->happen('ready2');

        exit;
    };

    is( PromiseTest::await($p3, \@todo), 'third resolve' );

    waitpid $pid, 0;
}

if (!caller) {
    __PACKAGE__->runtests();
}

1;
