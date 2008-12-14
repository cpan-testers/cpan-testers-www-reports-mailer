package CPAN::Testers::WWW::Reports::Mailer;

use warnings;
use strict;

use vars qw($VERSION);
$VERSION = '0.02';

=head1 NAME

CPAN::Testers::WWW::Reports::Mailer - CPAN Testers Reports Mailer

=head1 SYNOPSIS

  use CPAN::Testers::WWW::Reports::Mailer;

  # TO BE COMPLETED

=head1 DESCRIPTION

The CPAN Testers Reports Mailer takes the preferences set within the CPANPREFS
database, and uses them to filter out reports that the author does or does not
wish to be made aware of.

New authors are added to the system as a report for their first reported
distribution is submitted by a tester. Default settings are applied in the
first instance, with the author able to update these via the preferences
website.

Initially only a Daily Summary Report is available, in time a Weekly Summary
Report and the individual reports will also be available.

=cut

# -------------------------------------
# Library Modules

# -------------------------------------
# Variables

# -------------------------------------
# The Public Interface Subs

1;

__END__

=head1 SEE ALSO

L<CPAN::WWW::Testers::Generator>
L<CPAN::WWW::Testers>
L<CPAN::Testers::WWW::Statistics>

F<http://www.cpantesters.org/>,
F<http://stats.cpantesters.org/>,
F<http://wiki.cpantesters.org/>

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2008 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
