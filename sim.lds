OUTPUT_ARCH( "riscv" )

ENTRY( reset_vector )

SECTIONS
{
    /* Begining of code and text segment */
    . = 0x80000000;
    
    .text :
    {
        *(.text.init)
    }
    
    /* text: Program code section */
    .text :
    {
        *(.text)
    }
    
    
    /* bss: Uninitialized writeable data section */
    . = 0x80002000;
    _bss_start = .;
    .bss :
    {
        *(.bss)
        *(.bss.*)
    }
    
    _end = .;
}
