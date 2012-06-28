=head1 NAME

DynGig::Automata - A collection of automation frameworks

=cut
package DynGig::Automata;

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 MODULES

=head2 DynGig::Automata::CLI::Sequence::CTRL 

CLI for sequence control.

=head2 DynGig::Automata::CLI::Sequence::Run 

CLI for sequence run.

=head2 DynGig::Automata::CLI::Watcher::Exclude 

CLI for watcher exclude.

=head2 DynGig::Automata::CLI::Watcher::Run 

CLI for watcher run.

=head2 DynGig::Automata::CLI::Watcher::Service 

CLI for watcher service.

=head2 DynGig::Automata::MapReduce 

Sequential map/reduce automation framework.

=head2 DynGig::Automata::Sequence 

Sequential automation framework.

=head2 DynGig::Automata::Serial 

Process targets in serial batches.

=head2 DynGig::Automata::Thread 

Extends DynGig::Automata::Serial.

=head2 DynGig::Automata::EZDB::Alert 

Extends DynGig::Util::EZDB.

=head2 DynGig::Automata::EZDB::Exclude 

Extends DynGig::Util::EZDB.

=head1 AUTHOR

Kan Liu

=head1 COPYRIGHT and LICENSE

Copyright (c) 2010. Kan Liu

This program is free software; you may redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__END__
