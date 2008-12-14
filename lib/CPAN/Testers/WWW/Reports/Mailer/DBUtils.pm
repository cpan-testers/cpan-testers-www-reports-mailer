package CPAN::Testers::WWW::Reports::Mailer::DBUtils;

use warnings;
use strict;

use vars qw($VERSION);
$VERSION = '0.02';

=head1 NAME

CPAN::Testers::WWW::Reports::Mailer::DBUtils - Database Wrapper

=head1 SYNOPSIS

  use CPAN::Testers::WWW::Reports::Mailer::DBUtils;

  my $dbi = CPAN::Testers::WWW::Reports::Mailer::DBUtils->new({
                driver => 'CSV',
                file => '/var/www/mysite/db);
  sub errors { print STDERR "Error: $_[0], sql=$_[1]\n" }

  my @arr = $dbi->GetQuery('array',$sql);
  my @arr = $dbi->GetQuery('array',$sql,$bid);
  my @arr = $dbi->GetQuery('hash',$sql,$bid);

  my $id = $dbi->IDQuery($sql,$id,$name);
  $dbi->DoQuery($sql,$id);

  my $next = Iterator('array',$sql);
  my @row = &$next;

  my $next = Iterator('hash',$sql);
  my %row = &$next;

  $value = $dbi->Quote($value);

=head1 DESCRIPTION

The DBUtils package is a further database interface layer, providing a
collection of control methods to initiate the database connection, handle
errors and a smooth handover from the program to the database drivers.

=cut

# -------------------------------------
# Library Modules

use Carp;
use DBI;

use base qw(Class::Accessor::Fast);

# -------------------------------------
# Variables

# -------------------------------------
# The Public Interface Subs

=head2 CONSTRUCTOR

=over 4

=item new({})

The Constructor method. Can be called with an anonymous hash,
listing the values to be used to connect to and handle the database.

Values in the hash can be

  driver (*)
  database (+)
  dbfile (+)
  dbhost
  dbport
  dbuser
  dbpass

(*) These entries MUST exist in the hash.
(+) At least ONE of these must exist in the hash, and depend upon the driver.

Note that 'file' is for use with a flat file database, such as DBD::CSV.

=back

=cut

sub new {
    my ($self, %hash) = @_;

    # check we've got our mandatory fields
    croak("$self needs a driver!")      unless($hash{driver});
    croak("$self needs a database/file!")
            unless($hash{database} || $hash{dbfile});

    # create an attributes hash
    my $dbv = {
        'driver'     => $hash{driver},
        'database'   => $hash{database},
        'dbfile'     => $hash{dbfile},
        'dbhost'     => $hash{dbhost},
        'dbport'     => $hash{dbport},
        'dbuser'     => $hash{dbuser},
        'dbpass'     => $hash{dbpass},
        'AutoCommit' => defined $hash{AutoCommit} ? $hash{AutoCommit} : 1,
    };

    # create the object
    bless $dbv, $self;
    return $dbv;
}

=head2 PUBLIC INTERFACE METHODS

=over 4

=item GetQuery(type,sql,<list>)

  type - 'array' or 'hash'
  sql - SQL statement
  <list> - optional additional values to be inserted into SQL placeholders

The function performs a SELECT statement, which returns either a list of lists,
or a list of hashes. The difference being that for each record, the field
values are listed in the order they are returned, or via the table column
name in a hash.

=cut

sub GetQuery {
    my ($dbv,$type,$sql,@args) = @_;
    return ()   unless($sql);

    # if the object doesnt contain a reference to a dbh object
    # then we need to connect to the database
    $dbv = &_db_connect($dbv) if not $dbv->{dbh};

    # prepare the sql statement for executing
    my $sth;
    eval { $sth = $dbv->{dbh}->prepare($sql) };
    unless($sth) {
        croak("err=".$dbv->{dbh}->errstr.", sql=[$sql], args[".join(",",map{$_ || ''} @args)."]");
        return ();
    }

    # execute the SQL using any values sent to the function
    # to be placed in the sql
    if(!$sth->execute(@args)) {
        croak("err=".$sth->errstr.", sql=[$sql], args[".join(",",map{$_ || ''} @args)."]");
        return ();
    }

    my @result;
    # grab the data in the right way
    if ( $type eq 'array' ) {
        while ( my $row = $sth->fetchrow_arrayref() ) {
            push @result, [@{$row}];
        }
    } else {
        while ( my $row = $sth->fetchrow_hashref() ) {
            push @result, $row;
        }
    }

    # finish with our statement handle
    $sth->finish;
    # return the found datastructure
    return @result;
}

=item Iterator(type,sql,<list>)

  type - 'array' or 'hash'
  sql - SQL statement
  <list> - optional additional values to be inserted into SQL placeholders

The function performs a SELECT statement, which returns a subroutine reference
which can then be used to obtain either a list of lists, or a list of hashes.
The difference being that for each record, the field values are listed in the
order they are returned, or via the table column name in a hash.

=cut

sub Iterator {
    my ($dbv,$type,$sql,@args) = @_;
    return undef    unless($sql);

    # if the object doesnt contain a reference to a dbh object
    # then we need to connect to the database
    $dbv = &_db_connect($dbv) if not $dbv->{dbh};

    # prepare the sql statement for executing
    my $sth = $dbv->{dbh}->prepare($sql);
    unless($sth) {
        croak("err=".$dbv->{dbh}->errstr.", sql=[$sql], args[".join(",",map{$_ || ''} @args)."]");
        return undef;
    }

    # execute the SQL using any values sent to the function
    # to be placed in the sql
    if(!$sth->execute(@args)) {
        croak("err=".$sth->errstr.", sql=[$sql], args[".join(",",map{$_ || ''} @args)."]");
        return undef;
    }

    # grab the data in the right way
    if ( $type eq 'array' ) {
        return sub {
            if ( my $row = $sth->fetchrow_arrayref() ) { return @{$row}; }
            else { $sth->finish; return; }
        }
    } else {
        return sub {
            if ( my $row = $sth->fetchrow_hashref() ) { return %$row; }
            else { $sth->finish; return; }
        }
    }
}

=item DoQuery(sql,<list>)

  sql - SQL statement
  <list> - optional additional values to be inserted into SQL placeholders

The function performs an SQL statement. If performing an INSERT statement that
returns an record id, this is returned to the calling function.

=cut

sub DoQuery {
    my ($dbv,$sql,@args) = @_;
    $dbv->_doQuery($sql,0,@args);
}

=item IDQuery(sql,<list>)

  sql - SQL statement
  <list> - optional additional values to be inserted into SQL placeholders

The function performs an SQL statement. If performing an INSERT statement that
returns an record id, this is returned to the calling function.

=cut

sub IDQuery {
    my ($dbv,$sql,@args) = @_;
    return $dbv->_doQuery($sql,1,@args);
}

=item DoSQL(sql,<list>)

  sql - SQL statement
  <list> - optional additional values to be inserted into SQL placeholders

=cut

sub DoSQL {
    my ($dbv,$sql,@args) = @_;
    $dbv->_doQuery($sql,0,@args);
}

# _doQuery(sql,idrequired,<list>)
#
#  sql - SQL statement
#  idrequired - true if an ID value is required on return
#  <list> - optional additional values to be inserted into SQL placeholders
#
#The function performs an SQL statement. If performing an INSERT statement that
#returns an record id, this is returned to the calling function.

sub _doQuery {
    my ($dbv,$sql,$idrequired,@args) = @_;
    my $rowid = undef;

    return $rowid   unless($sql);

    # if the object doesnt contain a refrence to a dbh object
    # then we need to connect to the database
    $dbv = &_db_connect($dbv) if not $dbv->{dbh};

    if($idrequired) {
        # prepare the sql statement for executing
        my $sth = $dbv->{dbh}->prepare($sql);
        unless($sth) {
            croak("err=".$dbv->{dbh}->errstr.", sql=[$sql], args[".join(",",map{$_ || ''} @args)."]");
            return undef;
        }

        # execute the SQL using any values sent to the function
        # to be placed in the sql
        if(!$sth->execute(@args)) {
            croak("err=".$sth->errstr.", sql=[$sql], args[".join(",",map{$_ || ''} @args)."]");
            return undef;
        }

        if($dbv->{driver} =~ /mysql/i) {
            $rowid = $dbv->{dbh}->{mysql_insertid};
        } else {
            my $row;
            $rowid = $row->[0]  if( $row = $sth->fetchrow_arrayref() );
        }

    } else {
        eval { $dbv->{dbh}->do($sql, undef, @args) };
        if ( $@ ) {
            croak("err=".$dbv->{dbh}->errstr.", sql=[$sql], args[".join(",",map{$_ || ''} @args)."]");
            return -1;
        }

        $rowid = 1;     # technically this should be the number of succesful rows
    }


    ## Return the rowid we just used
    return $rowid;
}

=item Quote(string)

  string - string to be quoted

The function performs a DBI quote operation, which will quote a string
according to the SQL rules.

=cut

sub Quote {
    my $dbv  = shift;
    return undef    unless($_[0]);

    # Cant quote with DBD::CSV
    return $_[0]    if($dbv->{driver} =~ /csv/i);

    # if the object doesnt contain a refrence to a dbh object
    # then we need to connect to the database
    $dbv = &_db_connect($dbv) if not $dbv->{dbh};

    $dbv->{dbh}->quote($_[0]);
}

# -------------------------------------
# The Get & Set Methods Interface Subs

=item Get & Set Methods

The following accessor methods are available:

  driver
  database
  dbfile
  dbhost
  dbport
  dbuser
  dbpass

All functions can be called to return the current value of the associated
object variable, or be called with a parameter to set a new value for the
object variable.

(*) Setting these methods will take action immediately. All other access
methods require a new object to be created, before they can be used.

Examples:

  my $database = $dbi->database();
  $dbi->database('another');

=cut

__PACKAGE__->mk_accessors(qw(driver database dbfile dbhost dbport dbuser dbpass));

# -------------------------------------
# The Private Subs
# These modules should not have to be called from outside this module

sub _db_connect {
    my $dbv  = shift;

    my $dsn =   'dbi:' . $dbv->{driver};
    my %options = (
        RaiseError => 1,
        AutoCommit => $dbv->{AutoCommit},
    );

    if($dbv->{driver} =~ /ODBC/) {
        # all the info is in the Data Source repository

    } elsif($dbv->{driver} =~ /SQLite/i) {
        $dsn .=     ':dbname='   . $dbv->{database} if $dbv->{database};
        $dsn .=     ';host='     . $dbv->{dbhost}   if $dbv->{dbhost};
        $dsn .=     ';port='     . $dbv->{dbport}   if $dbv->{dbport};

        $options{sqlite_handle_binary_nulls} = 1;

    } else {
        $dsn .=     ':f_dir='    . $dbv->{dbfile}   if $dbv->{dbfile};
        $dsn .=     ':database=' . $dbv->{database} if $dbv->{database};
        $dsn .=     ';host='     . $dbv->{dbhost}   if $dbv->{dbhost};
        $dsn .=     ';port='     . $dbv->{dbport}   if $dbv->{dbport};
    }

    eval {
        $dbv->{dbh} = DBI->connect($dsn, $dbv->{dbuser}, $dbv->{dbpass}, \%options);
    };

    croak("Cannot connect to DB [$dsn]: $@")    if($@);
    return $dbv;
}

sub DESTROY {
    my $dbv = shift;
#   $dbv->{dbh}->commit     if defined $dbv->{dbh};
    $dbv->{dbh}->disconnect if defined $dbv->{dbh};
}

1;

__END__

=back

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

  Copyright (C) 2002-2008 Barbie for Miss Barbell Productions
  All Rights Reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
