# $Id: Message.pm,v 1.3 2005/12/17 15:07:00 joern Exp $

#-----------------------------------------------------------------------
# Copyright (C) 2002-2005 J�rn Reder <joern AT zyn.de>.
# All Rights Reserved. See file COPYRIGHT for details.
# 
# This module is part of Event::RPC, which is free software; you can
# redistribute it and/or modify it under the same terms as Perl itself.
#-----------------------------------------------------------------------

package Event::RPC::Message;

use Carp;
use strict;
use Storable;

my $DEBUG = 0;

sub get_sock			{ shift->{sock}				}

sub get_buffer			{ shift->{buffer}			}
sub get_length			{ shift->{length}			}
sub get_written			{ shift->{written}			}

sub set_buffer			{ shift->{buffer}		= $_[1]	}
sub set_length			{ shift->{length}		= $_[1]	}
sub set_written			{ shift->{written}		= $_[1]	}

sub new {
	my $class = shift;
	my ($sock) = @_;

	$sock->blocking(1);
	
	my $self = bless {
		sock	=> $sock,
		buffer	=> undef,
		length	=> 0,
		written => 0,
	}, $class;

	return $self;
}

sub read {
	my $self = shift;

	if ( not defined $self->{buffer} ) {
		my $length_packed;
		$DEBUG && print "DEBUG: going to read header...\n";
		my $rc = sysread ($self->get_sock, $length_packed, 4);
		$DEBUG && print "DEBUG: header read rc=$rc\n";
		die "DISCONNECTED" if !(defined $rc) || $rc == 0;
		$self->{length} = unpack("N", $length_packed);
		$DEBUG && print "DEBUG: packet size=$self->{length}\n";
		die "Incoming message too big"
			if $self->{length} > 4194304;
	}

	my $buffer_length = length($self->{buffer}||'');

	$DEBUG && print "DEBUG: going to read packet... (buffer_length=$buffer_length)\n";

	my $rc = sysread (
		$self->get_sock,
		$self->{buffer},
		$self->{length} - $buffer_length,
		$buffer_length
	);

	$DEBUG && print "DEBUG: packet read rc=$rc\n";

	return if not defined $rc;
	die "DISCONNECTED" if $rc == 0;

	$buffer_length = length($self->{buffer});

	$DEBUG && print "DEBUG: more to read... ($self->{length} != $buffer_length)\n"
		if $self->{length} != $buffer_length;

	return if $self->{length} != $buffer_length;

	$DEBUG && print "DEBUG: read finished, length=$buffer_length\n";

	my $data = Storable::thaw($self->{buffer});

	$self->{buffer} = undef;
	$self->{length} = 0;

	return $data;
}

sub read_blocked {
	my $self = shift;
	
	my $rc;
	$rc = $self->read while not defined $rc;
	
	return $rc;
}

sub write {
	my $self = shift;
	my ($data) = @_;

	$DEBUG && print "DEBUG: going to write...\n";

	if ( not defined $self->{buffer} ) {
		my $packed = Storable::freeze ($data);
		$self->{buffer} = pack("N", length($packed)).$packed;
		$self->{length} = length($self->{buffer});
		$self->{written} = 0;
	}

	my $rc = syswrite (
		$self->get_sock,
		$self->{buffer},
		$self->{length}-$self->{written},
		$self->{written},
	);

	$DEBUG && print "DEBUG: written rc=$rc\n";

	return if not defined $rc;

	$self->{written} += $rc;
	
	if ( $self->{written} == $self->{length} ) {
		$DEBUG && print "DEBUG: write finished\n";
		$self->{buffer} = undef;
		$self->{length} = 0;
		return 1;
	}

	$DEBUG && print "DEBUG: more to be written...\n";

	return;
}

sub write_blocked {
	my $self = shift;
	my ($data) = @_;
	
	$self->write($data) and return;
	
	my $finished = 0;
	$finished = $self->write while not $finished;
	
	1;
}

1;

__END__

=head1 NAME

Event::RPC::Message - Implementation of Event::RPC network protocol

=head1 SYNOPSIS

  # Internal module. No documented public interface.

=head1 DESCRIPTION

This module implements the network protocol of Event::RPC.
Objects of this class are created internally by Event::RPC::Server
and Event::RPC::Client and performs message passing over the
network.

=head1 AUTHORS

  J�rn Reder <joern at zyn dot de>

=head1 COPYRIGHT AND LICENSE

Copyright 2002-2005 by J�rn Reder.

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU Library General Public License as
published by the Free Software Foundation; either version 2.1 of the
License, or (at your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.

You should have received a copy of the GNU Library General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307
USA.

=cut