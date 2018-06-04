#define INT_KEY_DOWN    0x0001
#define INT_KEY_UP      0x0002
#define INT_KEY_ENTER   0x0004
#define INT_KEY_BACK    0x0008
#define INT_KEY_LEFT    0x0010
#define INT_KEY_RIGHT   0x0020

#define INT_M_TIME      0x8000

#define LCD_BASE        0x80000000
#define LCD_RS          *(               volatile char  *)(LCD_BASE + 0)
#define LCD_RW          *(               volatile char  *)(LCD_BASE + 1)
#define LCD_E           *(               volatile char  *)(LCD_BASE + 2)
#define LCD_DATA        *(               volatile char  *)(LCD_BASE + 3)


#define INTERRUPT_BASE  0x40000000
#define INTERRUPT_PEND  *(unsigned const volatile short *)(INTERRUPT_BASE + 0)
#define INTERRUPT_MASK  *(unsigned       volatile short *)(INTERRUPT_BASE + 2)
#define WFI             *(unsigned       volatile short *)(INTERRUPT_BASE + 4) = 0


#define M_TIME_BASE     0x20000000
#define M_TIME_CMP      *(unsigned       volatile short *)(M_TIME_BASE + 0)
#define M_TIME_RESET    *(unsigned       volatile short *)(M_TIME_BASE + 2) = 0

#define DEBOUNCE_BASE  0x10000000
#define KEY_ACK         *(unsigned       volatile short *)(DEBOUNCE_BASE + 0) = 0

unsigned char screen_pos;

const char top_animation[4][21] = {
    { 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x00 },
    { 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0x00 },
    { 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0x00 },
    { 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0xFF, 0x20, 0xFF, 0xFF, 0x00 },
};

const char side_animation[4] = {
    0xFF, 0xFF, 0xFF, 0x20
};

const char * welcome_message = "STARTING UP";


struct value
{
    const char         * const name;
    unsigned long long * const addr;
};

const unsigned long long my_val_rom = 0xDEADBEEFDEADBEEF;

unsigned long long my_val_ram1;
unsigned long long my_val_ram2;

const struct value my_values[] = {
    { "my_val_rom",  (unsigned long long *)&my_val_rom },
    { "my_val_ram1", &my_val_ram1 },
    { "my_val_ram2", &my_val_ram2 }
};

struct menu_elem
{
    const char * const string;
    void (* const func)( void * arg );
    void * const arg;
};

struct menu
{
    const char * const title;
    const struct menu_elem * const list;
    const int list_size;
};

const struct menu main_menu;
static void do_menu( void * arg );
static void do_show_value( void * arg );
static void do_set_value( void * arg );

const struct menu_elem main_menu_list[] = {
    { "1. show val_rom",  do_show_value, (void*)&my_values[0] },
    { "2. show val_ram1", do_show_value, (void*)&my_values[1] },
    { "3. set  val_ram1", do_set_value,  (void*)&my_values[1] },
    { "4. show val_ram2", do_show_value, (void*)&my_values[2] },
    { "5. set  val_ram2", do_set_value,  (void*)&my_values[2] },
};

const struct menu main_menu = {
    "MAIN MENU",
    main_menu_list,
    sizeof( main_menu_list ) / sizeof( main_menu_list[0] )
};

static void delay( unsigned short msecs )
{
    M_TIME_CMP  = msecs;
    M_TIME_RESET;
    
    INTERRUPT_MASK = INT_M_TIME;
    WFI;
}

static unsigned short wait_key( unsigned short keys )
{
    unsigned short int_key = 0;
    
    while( (int_key & keys) == 0 )
    {
        INTERRUPT_MASK = INT_KEY_DOWN | INT_KEY_UP | INT_KEY_ENTER | INT_KEY_BACK | INT_KEY_LEFT | INT_KEY_RIGHT;
        WFI;
        int_key = INTERRUPT_PEND;
        KEY_ACK;
    }
    
    return int_key;
}

static void lcd_command( char i )
{
    LCD_DATA = i;       //put data on output Port
    LCD_RS   = 0;       //D/I=LOW : send instruction
    LCD_RW   = 0;       //R/W=LOW : Write
    LCD_E    = 1;
    delay(1);           //enable pulse width >= 300ns
    LCD_E    = 0;       //Clock enable: falling edge
}

static void lcd_write( char i )
{
    LCD_DATA = i;       //put data on output Port
    LCD_RS   = 1;       //D/I=HIGH : send data
    LCD_RW   = 0;       //R/W=LOW : Write
    LCD_E    = 1;
    delay(1);           //enable pulse width >= 300ns
    LCD_E    = 0;       //Clock enable: falling edge
}

static void lcd_set_pos( unsigned char pos)
{
    if( !(  (pos <= 27) || ( (pos >= 40) && (pos <= 57) )  ) )
    {
        pos = 0;
    }
    
    lcd_command( pos | 0x80 );
    screen_pos = pos;
}

static int lcd_inc_addr()
{
    int is_newline = 1;
    if(      screen_pos == 0x13 ){ screen_pos = 0x40; }
    else if( screen_pos == 0x53 ){ screen_pos = 0x14; }
    else if( screen_pos == 0x27 ){ screen_pos = 0x54; }
    else if( screen_pos == 0x67 ){ screen_pos = 0x00; }
    else
    {
        is_newline = 0;
        screen_pos++;
    }
    
    lcd_set_pos( screen_pos );
    
    return is_newline;
}

static void lcd_home()
{
    if( screen_pos <= 0x13)
    {
        screen_pos = 0;
    }
    else if( (screen_pos >= 0x14) && (screen_pos <= 0x27) )
    {
        screen_pos = 0x14;
    }
    else if( (screen_pos >= 0x40) && (screen_pos <= 0x53) )
    {
        screen_pos = 0x40;
    }
    else
    {
        screen_pos = 0x54;
    }
}

static void lcd_init()
{
    LCD_E = 0;
    delay(100);         //Wait >40 msec after power is applied
    lcd_command(0x30);  //command 0x30 = Wake up
    delay(30);          //must wait 5ms, busy flag not available
    lcd_command(0x30);  //command 0x30 = Wake up #2
    delay(10);          //must wait 160us, busy flag not available
    lcd_command(0x30);  //command 0x30 = Wake up #3
    delay(10);          //must wait 160us, busy flag not available
    lcd_command(0x38);  //Function set: 8-bit/2-line
    lcd_command(0x10);  //Set cursor
    lcd_command(0x0c);  //Display ON; Cursor ON
    lcd_command(0x06);  //Entry mode set
    
    lcd_set_pos(0);
}

static void print_char( char c )
{
    lcd_write( c );
    lcd_inc_addr();
}

static void print_spaces( int num_spaces )
{
    while( num_spaces-- > 0 )
    {
        print_char( ' ' );
    }
}

static unsigned int print_str( const char * s )
{
    const char * start = s;
    while( *s != 0x00 )
    {
        if( *s == '\n' )
        {
            while(1)
            {
                lcd_write( ' ' );
                if( lcd_inc_addr() == 1 ){ break; }
            }
        }
        else
        {
            print_char( *(s++) );
        }
    }
    
    return s - start;
}

static void lcd_clear()
{
    lcd_set_pos(0);
    print_spaces(80);
}

static unsigned int str_len( const char * s )
{
    const char * start = s;
    while( *s != 0 )
        s++;
    
    return (unsigned int)(s - start);
}

const char convert_hex[] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

static void print_ull_hex( unsigned long long h )
{
    char to_print[16];
    
    for( int i = 0; i < 16; i++ )
    {
        to_print[i] = convert_hex[h % 16];
        h >>= 4;
    }
    
    for( int i = 15; i >= 0; i-- )
    {
        print_char( to_print[i] );
    }
}

static void do_set_value( void * arg )
{
    struct value * my_value = (struct value *)arg;
    const char * set_string = "SET:";
    const char underline    = 0xB0;
    unsigned short int_key;
    
    unsigned long long curr_value = 0;
    int curr_pos = 0;
    
    lcd_clear();
    
    while( 1 )
    {
        print_str(set_string);
        print_str("\n");
        
        print_spaces(1);
        print_str(my_value->name);
        print_str("\n");
        
        print_spaces(2);
        print_ull_hex( curr_value );
        print_str("\n");
        
        print_spaces( 18 - ( 1 + curr_pos));
        print_char( underline );
        print_str("\n");
        
        int_key = wait_key( INT_KEY_DOWN | INT_KEY_UP | INT_KEY_ENTER | INT_KEY_BACK | INT_KEY_LEFT | INT_KEY_RIGHT );
        
        if(      (int_key & INT_KEY_DOWN ) != 0 )
        {
            unsigned int my_adder = 1 << ((unsigned int)(curr_pos) << 4);
            curr_value -= my_adder;
        }
        else if( (int_key & INT_KEY_UP   ) != 0)
        {
            unsigned int my_adder = 1 << ((unsigned int)(curr_pos) << 4);
            curr_value += my_adder;
        }
        else if( (int_key & INT_KEY_LEFT) != 0)
        {
            curr_pos++;
            if( curr_pos == 8 )
            {
                curr_pos = 0;
            }
        }
        else if( (int_key & INT_KEY_RIGHT) != 0)
        {
            curr_pos--;
            if( curr_pos == -1 )
            {
                curr_pos = 7;
            }
        }
        else if( (int_key & INT_KEY_ENTER) != 0)
        {
            *(my_value->addr) = curr_value;
            return;
        }
        else
        {
           return;
        }
        
    }
}

static void do_show_value( void * arg )
{
    struct value * my_value = (struct value *)arg;
    const char * name_string   = "NAME :";
    const char * value_string  = "VALUE:";
    
    lcd_clear();
    
    print_str(name_string);
    print_str("\n");
    
    print_spaces(1);
    print_str(my_value->name);
    print_str("\n");
    
    print_str(value_string);
    print_str("\n");
    
    print_spaces(1);
    print_ull_hex( *(my_value->addr) );
    print_str("\n");
    
    wait_key( INT_KEY_BACK );
}

static void do_menu( void * arg )
{
    const struct menu * my_menu = (const struct menu *)arg;
    int curr_index      = 0;
    int last_index      = my_menu->list_size - 1;
    int min_dis_index   = 0;
    int max_dis_index   = 2;
    unsigned short int_key;
    
    const char arrow    = 0x7E;
    
    lcd_clear();
    
    while( 1 )
    {
        print_spaces(1);
        print_str(my_menu->title);
        print_str("\n");
        
        for( int i = min_dis_index; i <= max_dis_index; i++)
        {
            if( i > last_index )
            {
                print_str("\n");
            }
            else
            {
                if( i == curr_index )
                {
                    print_char(arrow);
                }
                else
                {
                    print_spaces(1);
                }
                
                print_str(my_menu->list[i].string);
                print_str("\n");
            }
        }
        
        int_key = wait_key( INT_KEY_DOWN | INT_KEY_UP | INT_KEY_ENTER | INT_KEY_BACK );
        
        if(      (int_key & INT_KEY_DOWN ) != 0 )
        {
            if( curr_index < last_index )
            {
                curr_index++;
                if( curr_index > max_dis_index )
                {
                    min_dis_index++;
                    max_dis_index++;
                }
            }
        }
        else if( (int_key & INT_KEY_UP   ) != 0)
        {
            if( curr_index > 0 )
            {
                curr_index--;
                if( curr_index < min_dis_index )
                {
                    min_dis_index--;
                    max_dis_index--;
                }
            }
        }
        else if( (int_key & INT_KEY_ENTER) != 0)
        {
            my_menu->list[curr_index].func( my_menu->list[curr_index].arg );
        }
        else
        {
           return;
        }
        
    }
}

static void print_start( void )
{
    lcd_clear();

    int top_pos = 0;
    int bot_pos = 1;
    int side_0  = 2;
    int side_1  = 3;
    int side_2  = 1;
    int side_3  = 0;
    
    for( int i = 0; i < 8; i++ )
    {
        print_str (&top_animation[top_pos][0]);
        
        print_char(side_animation[side_0]);
        print_spaces(3);
        print_str(welcome_message);
        print_spaces(4);
        print_char(side_animation[side_1]);
        
        print_char(side_animation[side_2]);
        print_spaces(18);
        print_char(side_animation[side_3]);
        
        print_str(&top_animation[bot_pos][0]);
        
        top_pos++;
        bot_pos--;
        side_0++;
        side_1++;
        side_2++;
        side_3++;
 
        if( top_pos ==  4 ){ top_pos = 0; }
        if( bot_pos == -1 ){ bot_pos = 3; }
        if( side_0  ==  4 ){ side_0  = 0; }
        if( side_1  ==  4 ){ side_1  = 0; }
        if( side_2  ==  4 ){ side_2  = 0; }
        if( side_3  ==  4 ){ side_3  = 0; }
        
        delay(500);
    }
}

void start( void )
{
    my_val_ram1 = 0;
    my_val_ram2 = 0x0123456789ABCDEF;
    
    lcd_init();
    print_start();
    
    while( 1 )
    {
        do_menu((void*)&main_menu);
    }
}
