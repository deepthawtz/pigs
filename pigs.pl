#!/usr/bin/perl

use warnings;
use strict;
use Proc::ProcessTable;
use Getopt::Long;
use Pod::Usage qw(pod2usage);
# use Data::Dumper qw(Dumper);   


my ($cumul, $indef, $graph, $opt_help);
GetOptions(
   'indef=i' => \$indef,
   'cumul=i' => \$cumul,
   'graph'   => \$graph,
   'help!'   => \$opt_help,
) or pod2usage( -verbose => 1 ) && exit;
pod2usage( -verbose => 1 ) && exit if defined $opt_help;
die( "Mututally exclusive arguments: [-i] and [-c]\n" ) if ( defined $cumul && defined $indef );

my $proc   = new Proc::ProcessTable( cache_ttys => 1 );
my @fields = $proc->fields;
my $ref    = $proc->table;


my %user_table;
foreach my $p ( @{$proc->table} ) {
   my %user_info = (
       proc      => $p->cmndline,
       cpu_perc  => $p->pctcpu,
       cpu_sec   => scalar($p->start),
       pctmem    => $p->pctmem,
   ) unless ( $p->euid == 0 );
   if (%user_info) {
       my $time = time;
       my $user = getpwuid($p->euid);
       $user_table{$user}->{$time}->{proc}++;
       $user_table{$user}->{$time}->{cpu_perc} += $p->pctcpu;
       $user_table{$user}->{$time}->{cpu_sec} += $p->start;
       $user_table{$user}->{$time}->{pctmem} += $p->pctmem;
   }
}

# print Dumper \%user_table;
# exit;

report() unless $graph;

if ($graph) { 
   # half implemented, but close...

   use RRD::Simple;
   my $rrd = RRD::Simple->new( );
   my $rrdfile = "dump-pig.rrd"; 
   rrd_create($rrd, $rrdfile);
   rrd_read($rrd, $rrdfile);
   rrd_update($rrd, $rrdfile);
}

sub rrd_create {
   my ($r, $rfile) = @_;

   $r->create( $rfile, 'day',
       proc     => "COUNTER",
       cpu_perc => "GAUGE", 
       cpu_sec  => "COUNTER",
       pctmem   => "GAUGE",
   );
}
sub rrd_read {
   my ($r, $rfile) = @_;

   my $info = $r->info($rfile);
#    print Dumper $info;
}

sub rrd_update {
   my ($r, $rfile) = @_;

   foreach my $name ( keys %user_table ) {
       for my $time ( keys %{ $user_table{$name} } ) {
           $r->update( $rfile, 
               proc     => $user_table{$name}->{$time}->{proc}, 
               cpu_perc => $user_table{$name}->{$time}->{cpu_sec}, 
               cpu_sec  => $user_table{$name}->{$time}->{cpu_perc},  
               pctmem   => $user_table{$name}->{$time}->{pctmem},            
           );
       }
   }
}

sub report {
   use Perl6::Form;
   my $title = "PIGS REPORT";

   print form
   '                        [ {||||||||||||||} ]                    ',
                                    $title, 
   '    .==========================================================.',
   '    |  USER      | PROCESSES |  CPU (ms)  |  CPU % | MEMORY %  |',
   '    |------------+-----------+------------+--------+-----------|',
   ;

   foreach my $name ( keys %user_table ) {
       for my $time ( keys %{ $user_table{$name} } ) {
           print form {bullet => '*'},
           '    |* {<<<<<<<<}|    {|}    |{||||||||||}| {>>.}% |  {>>.}%   |',
           $name,  
           $user_table{$name}->{$time}->{proc}, 
           $user_table{$name}->{$time}->{cpu_sec}, 
           $user_table{$name}->{$time}->{cpu_perc},  
           $user_table{$name}->{$time}->{pctmem},            
           '    |------------+-----------+------------+--------+-----------|',
           ;
       }
   }
}




__END__

=head1 NAME

pigs.pl   -   Monitor users and the resources which they consume.   



=head1 SYNOPSIS

B< pigs.pl [OPTIONS] [SECONDS] >


=head1 OPTIONS

=over 4

=item B< -i --indef [SECONDS] >  


Shows a snapshot (indefinitely) for [SECONDS] seconds.

=item B< -c --cumul [SECONDS] >

Report cumulative statistics over a period of [SECONDS] seconds.

=item B< -g --graph >

Generate a colorized png graph based on statistics.

=item B< -h --help  >

Prints this short usage message and exits.

=back



=head1 REQUIREMENTS

Proc::ProcessTable
Perl6::Form
RRD::Simple
rrdtool



=head1 DESCRIPTION

A useful system resource report for the system administrator. Pigs will
show you effectively who is being a pig on your system and how much
resources they are using. 



=head1 TODO

Tie in rrd data gathering to arguments (-c) and (-i). 

$rrd->graph( 
       title => "Fancy graph",
       vertical_label => "CPU Percent",
       upper_limit    => 100,
       lower_limit    => 0,
       sources => [ qw/ cpu_perc / ],
   );



=head1 AUTHOR

Dylan Clendenin

=cut
