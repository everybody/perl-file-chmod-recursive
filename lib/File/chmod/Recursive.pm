package File::chmod::Recursive;

#######################
# LOAD MODULES
#######################
use strict;
use warnings FATAL => 'all';
use Carp qw(croak carp);
use Cwd qw(abs_path);
use File::Find qw(finddepth);
use File::chmod qw(chmod);

#######################
# VERSION
#######################
our $VERSION = '0.02';

#######################
# EXPORT
#######################
use base qw(Exporter);
our (@EXPORT);

@EXPORT = qw(chmod_recursive);

#######################
# CHMOD RECURSIVE
#######################
sub chmod_recursive {

    # Read Input
    my @in = @_;

    # Default mode
    my $mode = {
        files       => q(),
        dirs        => q(),
        match_dirs  => {},
        match_files => {},
    };

    # Default _find_ settings
    my %find_settings = (
        follow   => 0,  # Do not Follow symlinks
        no_chdir => 1,  # Do not chdir
    );

    # Check Input
    my $dir;
    if ( ref $in[0] eq 'HASH' ) {

        # Usage chmod_recursive({}, $dir);

        # Both files and Directories are required
        $mode->{files} = $in[0]->{files} || q();
        $mode->{dirs}  = $in[0]->{dirs}  || q();

        # Check for match
        if ( $in[0]->{match} ) {
            croak "Hash ref expected for _match_"
                unless ( ref $in[0]->{match} eq 'HASH' );
            $mode->{match_dirs} =
                { %{ $mode->{match_dirs} }, $in[0]->{match} };
            $mode->{match_files} =
                { %{ $mode->{match_files} }, $in[0]->{match} };
        } ## end if ( $in[0]->{match} )

        # Check for match files
        if ( $in[0]->{match_files} ) {
            croak "Hash ref expected for _match_files_"
                unless ( ref $in[0]->{match_files} eq 'HASH' );
            $mode->{match_files} =
                { %{ $mode->{match_files} }, $in[0]->{match} };
        } ## end if ( $in[0]->{match_files...})

        # Check for match dirs
        if ( $in[0]->{match_dirs} ) {
            croak "Hash ref expected for _match_dirs_"
                unless ( ref $in[0]->{match_dirs} eq 'HASH' );
            $mode->{match_dirs} =
                { %{ $mode->{match_dirs} }, $in[0]->{match} };
        } ## end if ( $in[0]->{match_dirs...})

        # Check for _find_ settings
        if ( $in[0]->{follow_symlinks} ) {
            $find_settings{follow}      = 1;  # Follow Symlinks
            $find_settings{follow_skip} = 2;  # Skip duplicates
        }
        if ( $in[0]->{depth_first} ) {
            $find_settings{bydepth} = 1;
        }
    } ## end if ( ref $in[0] eq 'HASH')

    else {

        # Usage chmod_recursive($mode, $dir);

        # Set modes
        $mode->{files} = $in[0];
        $mode->{dirs}  = $in[0];
    } ## end else [ if ( ref $in[0] eq 'HASH')]

    # Get directory
    $dir = $in[1] || croak "Directory not provided";
    $dir = abs_path($dir);
    if ( -l $dir ) {
        $dir = readlink($dir) || croak "Failed to resolve symlink $dir";
    }
    croak "$dir is not a directory" unless -d $dir;

    # Run chmod
    my @updated;
    {

        # Turn off warnings for file find
        no warnings 'File::Find';
        find(
            {
                %find_settings,
                wanted => sub {

                    # The main stuff

                    # Get full path
                    my $path = $File::Find::name;

                    if ( not -l $path ) { # Do not set permissions on symlinks

                        # Process files
                        if ( -f $path ) {

                            # Process Matches
                            my $file_isa_match = 0;
                            foreach my $match_re (
                                keys %{ $mode->{match_files} } )
                            {
                                next unless ( $path =~ m{$match_re} );
                                $file_isa_match = 1;
                                if (
                                    chmod(
                                        $mode->{match_files}->{$match_re},
                                        $path
                                    )
                                    )
                                {
                                    push @updated, $path;
                                } ## end if ( chmod( $mode->{match_files...}))
                            } ## end foreach my $match_re ( keys...)

                            # Process non-matches
                            if (

                                # Skip processed
                                ( not $file_isa_match )

                                # And we're updating files
                                and ( $mode->{files} )

                                # And succesfully updated
                                and ( chmod( $mode->{files}, $path ) )
                                )
                            {
                                push @updated, $path;
                            } ## end if ( ( not $file_isa_match...))
                        } ## end if ( -f $path )

                        # Process Dirs
                        elsif ( -d $path ) {

                            # Process Matches
                            my $dir_isa_match = 0;
                            foreach
                                my $match_re ( keys %{ $mode->{match_dirs} } )
                            {
                                next unless ( $path =~ m{$match_re} );
                                $dir_isa_match = 1;
                                if (
                                    chmod(
                                        $mode->{match_dirs}->{$match_re},
                                        $path
                                    )
                                    )
                                {
                                    push @updated, $path;
                                } ## end if ( chmod( $mode->{match_dirs...}))
                            } ## end foreach my $match_re ( keys...)

                            # Process non-matches
                            if (

                                # Skip processed
                                ( not $dir_isa_match )

                                # And we're updating files
                                and ( $mode->{dirs} )

                                # And succesfully updated
                                and ( chmod( $mode->{dirs}, $path ) )
                                )
                            {
                                push @updated, $path;
                            } ## end if ( ( not $dir_isa_match...))
                        } ## end elsif ( -d $path )

                    } ## end if ( not -l $path )

                },
            },
            $dir
        );
    }

    # Done
    return scalar @updated;
} ## end sub chmod_recursive

#######################
1;

__END__

#######################
# POD SECTION
#######################
=pod

=head1 NAME

File::chmod::Recursive

=head1 DESCRIPTION

Run chmod recursively against directories

=head1 SYNOPSIS

	use File::chmod::Recursive;  # Exports 'chmod_recursive' by default

	# Apply identical permissions to everything
	#   Similar to chmod -R
	chmod_recursive( 0755, '/path/to/directory' );

	# Apply permissions selectively
	chmod_recursive(
	    {
	        dirs  => 0755,       # Mode for directories
	        files => 0644,       # Mode for files

	        # Match both directories and files
	        match => {
	            qr/\.sh|\.pl/ => 0755,
	            qr/\.gnupg/   => 0600,
	        },

	        # You can also match files or directories selectively
	        match_dirs  => { qr/\/logs\//    => 0775, },
	        match_files => { qr/\/bin\/\S+$/ => 0755, },
	    },
	    '/path/to/directory'
	);

=head1 FUNCTIONS

=over

=item chmod_recursive(MODE, $path)

=item chmod_recursive(\%options, $path)

This function accepts two parameters. The first is either a I<MODE> or an
I<options hashref>. The second is the directory to work on. It returns the
number of files successfully changed, similar to
L<chmod|http://perldoc.perl.org/functions/chmod.html>.

When using a I<hashref> for selective permissions, the following options are
valid -

	{
	    dirs  => MODE,  # Default Mode for directories
	    files => MODE,  # Default Mode for files

	    # Match both directories and files
	    match => { qr/<some condition>/ => MODE, },

	    # Match files only
	    match_files => { qr/<some condition>/ => MODE, },

	    # Match directories only
	    match_dirs => { qr/<some condition>/ => MODE, },

	    # Follow symlinks. OFF by default
	    follow_symlinks => 0,

	    # Depth first tree walking. ON by default (default _find_ behavior)
	    depth_first => 1,
	}
    
In all cases the I<MODE> is whatever L<File::chmod> accepts.

=back

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-file-chmod-recursive@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

-   L<File::chmod>

-   L<chmod|http://perldoc.perl.org/functions/chmod.html>

-   L<Perl Monks thread on recursive perl
chmod|http://www.perlmonks.org/?node_id=61745>

=head1 AUTHOR

Mithun Ayachit  C<< <mithun@cpan.org> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011, Mithun Ayachit C<< <mithun@cpan.org> >>. All rights
reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE
SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE
STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE
SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND
PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE,
YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY
COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE
SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING BUT NOT LIMITED TO
LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR
THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut
