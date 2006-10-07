#!/usr/bin/perl
# Create a large set of users and populate groups with them
# (group size 10000/5000/2500/..)

undef $/;
for my $user ( 1 .. 10000 ) {
    my $username = "TestUser$user";
    open( U, ">data/Main/TestUser$username.txt" ) || die $!;
    print U "   * E-mail: $username\@example.com\n";
    close(U);
    for my $group ( 1, 2, 4, 8, 16 ) {
        if ( ( $user % $group ) eq 0) {
            my $groupname = "Test${group}Group";
            my @cur;
            my @members;
            if ( -e "data/Main/$groupname.txt" ) {
                open( G, "<data/Main/$groupname.txt" ) || die $!;
                @cur = <G>;
                $cur[0] =~ s/^.*= //;
                $cur[0] .= ", Main.$username";
                push( @members, split( /,\s*/, $cur[0] ) );
                close(G);
            }
            else {
                $cur[0] .= "Main.$username";
                push( @members, $cur[0] );
            }

            open( G, ">data/Main/$groupname.txt" ) || die $!;
            print G "   * Set GROUP = ", join( ', ', @members ), "";
            close(G);
        }
    }
}
