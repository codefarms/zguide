#!/usr/bin/perl
=pod

Task worker - design 2

Adds pub-sub flow to receive and respond to kill signal

Author: Daisuke Maki (lestrrat)
Original Author: Alexander D'Archangel (darksuji) <darksuji(at)gmail(dot)com>

=cut

use strict;
use warnings;
use 5.10.0;

use IO::Handle;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_PULL ZMQ_PUSH ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_POLLIN);
use zhelpers;


my $context = zmq_init();

# Socket to receive messages on
my $receiver = zmq_socket($context, ZMQ_PULL);
zmq_connect($receiver, 'tcp://localhost:5557');

# Socket to send messages to
my $sender = zmq_socket($context, ZMQ_PUSH);
zmq_connect($sender, 'tcp://localhost:5558');

# Socket for control input
my $controller = zmq_socket($context, ZMQ_SUB);
zmq_connect($controller, 'tcp://localhost:5559');
zmq_setsockopt($controller, ZMQ_SUBSCRIBE, '');

# Process messages from receiver and controller
my $loop = 1;
my @poller = (
    {
        socket  => $receiver,
        events  => ZMQ_POLLIN,
        callback => sub {
            my $workload = s_recv($receiver);

            # Do the work
            s_sleep($workload);

            # Send results to sink
            s_send($sender, '');

            # Simple progress indicator for the viewer
            STDOUT->printflush('.');
        }
    }, {
        socket  => $controller,
        events  => ZMQ_POLLIN,
        callback => sub {
            # Any waiting controller command acts as 'KILL'
            $loop = 0;
        }
    },
);

# Process messages from both sockets
while ($loop) {
    zmq_poll(\@poller);
}
# Finished
