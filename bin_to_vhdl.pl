#!/usr/bin/perl

use warnings;
use strict;
use autodie;

unless ( scalar @ARGV == 4 )
{
    die "Use: ./bin_to_vhdl.pl bin_file_name vhdl_file_name rom_address init_offset\n\n";
}

my_main( $ARGV[0], $ARGV[1], $ARGV[2], $ARGV[3] );

exit 0;

sub my_main
{
    my $bin_file_name  = shift;
    my $vhdl_file_name = shift;
    my $rom_address = shift;
    my $init_offset = shift;
    
    my $bytes = slurp_bin_file( $bin_file_name );
    
    write_vhdl_file( $vhdl_file_name, $bytes, $rom_address, $init_offset );
}

sub write_vhdl_file
{
    my $vhdl_file_name = shift;
    my $bytes = shift;
    my $rom_address = shift;
    my $init_offset = shift;
    
    open my $vhd_fh_0, '>', "${vhdl_file_name}_0.vhd"
        or die "Could not open vhdl file |${vhdl_file_name}_0.vhd| says |$!|\n\n";
    
    open my $vhd_fh_1, '>', "${vhdl_file_name}_1.vhd"
        or die "Could not open vhdl file |${vhdl_file_name}_1.vhd| says |$!|\n\n";
    
    open my $vhd_fh_2, '>', "${vhdl_file_name}_2.vhd"
        or die "Could not open vhdl file |${vhdl_file_name}_2.vhd| says |$!|\n\n";
    
    open my $vhd_fh_3, '>', "${vhdl_file_name}_3.vhd"
        or die "Could not open vhdl file |${vhdl_file_name}_3.vhd| says |$!|\n\n";
    
    my @vhd_fhs = ($vhd_fh_0, $vhd_fh_1, $vhd_fh_2, $vhd_fh_3);
    my $fh_select = 0;
    
    foreach my $byte ( @{ $bytes })
    {
        my $string = sprintf "(%d + %d) => x\"%02x\", ", $rom_address, $init_offset, ord( $byte );
        my $vhd_fh = $vhd_fhs[$fh_select];
        print $vhd_fh $string;
        $fh_select++;
        if ( $fh_select == 4 )
        {
            $fh_select = 0;
            $init_offset++;
        }
    }
}

sub slurp_bin_file
{
    my $bin_file_name  = shift;
    my @bytes = ();
    
    open my $bin_fh, '<:raw', $bin_file_name 
        or die "Could not open binary file |$bin_file_name| says |$!|\n\n";
    
    while( 1 )
    {
        my $bytes_read = read $bin_fh, my $new_byte, 1;
        
        if( $bytes_read == 1 )
        {
            push @bytes, $new_byte;
        }
        elsif( $bytes_read == 0 )
        {
            last;
        }
        else
        {
            print "problem reading file, trying again!!!\n";
        }
    }
    
    return \@bytes;
}
