#define INT_KEY_DOWN  0x001
#define INT_KEY_UP    0x002
#define INT_KEY_ENTER 0x004
#define INT_KEY_BACK  0x008
#define INT_KEY_LEFT  0x010
#define INT_KEY_RIGHT 0x020

#define INT_M_TIME    0x800

#define LCD_OFFSET 0x00004000

#define CLEAR_LCD        *(char volatile *)(                       LCD_OFFSET) = 0

#define PRINT_LCD( add ) *(char volatile *)((unsigned long)(add) + LCD_OFFSET) = 1

#define M_TIME_BASE     0x00008000
#define M_TIME_CMP      *(unsigned       volatile short *)(M_TIME_BASE + 0)

#define M_TIME_RESET    *(unsigned       volatile char  *)(M_TIME_BASE + 2) = 0

#define INTERRUPT_BASE  0x0000C000
#define INTERRUPT_PEND  *(unsigned const volatile short *)(INTERRUPT_BASE + 0)
#define INTERRUPT_MASK  *(unsigned       volatile short *)(INTERRUPT_BASE + 2)

#define WFI             *(unsigned       volatile char  *)(INTERRUPT_BASE + 4) = 0

#define DEBOUNCE_BASE  0x00010000

#define KEY_ACK         *(unsigned       volatile char  *)(0x00010000) = 0

struct value
{
    const char   * const name;
    unsigned int * const addr;
};

const unsigned int my_val_rom = 0xDEADBEEF;

unsigned int my_val_ram1;
unsigned int my_val_ram2;

const struct value my_values[] = {
    { "my_val_rom",  (unsigned int *)&my_val_rom },
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
    { "1. show my_val_rom",  do_show_value, (void*)&my_values[0] },
    { "2. show my_val_ram1", do_show_value, (void*)&my_values[1] },
    { "3. set  my_val_ram1", do_set_value,  (void*)&my_values[1] },
    { "4. show my_val_ram2", do_show_value, (void*)&my_values[2] },
    { "5. set  my_val_ram2", do_set_value,  (void*)&my_values[2] },
};

const struct menu main_menu = {
    "MAIN MENU",
    main_menu_list,
    sizeof( main_menu_list ) / sizeof( main_menu_list[0] )
};

static unsigned int str_len( const char * s )
{
    const char * start = s;
    while( *s != 0 )
        s++;
    
    return (unsigned int)(s - start);
}

static void finish_line( unsigned int curr_len )
{
    const char * space_1 = " ";
    
    while( curr_len++ < 20 )
    {
        PRINT_LCD(space_1);
    }
}

const char convert_hex[] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

static void print_int_hex( unsigned int h )
{
    char to_print[16];
    
    for( int i = 0; i < 16; i+=2 )
    {
        to_print[i]   = convert_hex[h % 16];
        to_print[i+1] = 0;
        h >>= 4;
    }
    
    for( int i = 14; i >= 0; i-=2 )
    {
        PRINT_LCD(&to_print[i]);
    }
}

static void do_set_value( void * arg )
{
    struct value * my_value = (struct value *)arg;
    const char * space_3       = "   ";
    const char * set_string    = "SET  : ";
    const char * value_string  = "VALUE: ";
    const char * space_20      = "                    ";
    const char * underline     = "X";
    unsigned short int_keys;
    
    unsigned int curr_value = 0;
    int curr_pos = 0;
    
    CLEAR_LCD;
    
    while( 1 )
    {
        PRINT_LCD(space_3);
        PRINT_LCD(set_string);
        PRINT_LCD(my_value->name);
        finish_line( 3 + str_len(set_string) + str_len(my_value->name));
        
        PRINT_LCD(space_20);
        
        PRINT_LCD(space_3);
        PRINT_LCD(value_string);
        print_int_hex( curr_value );
        finish_line( 3 + str_len(value_string) + 8);
        
        finish_line( 20 - (3 + str_len(value_string) + 8 - 1 - curr_pos));
        PRINT_LCD(underline);
        finish_line( 3 + str_len(value_string) + 8 - curr_pos);
        
        INTERRUPT_MASK = INT_KEY_DOWN | INT_KEY_UP | INT_KEY_ENTER | INT_KEY_BACK | INT_KEY_LEFT | INT_KEY_RIGHT;
        WFI;
        
        int_keys = INTERRUPT_PEND;
        KEY_ACK;
        
        if(      (int_keys & INT_KEY_DOWN ) != 0 )
        {
            unsigned int my_adder = 1 << ((unsigned int)(curr_pos) << 4);
            curr_value -= my_adder;
        }
        else if( (int_keys & INT_KEY_UP   ) != 0)
        {
            unsigned int my_adder = 1 << ((unsigned int)(curr_pos) << 4);
            curr_value += my_adder;
        }
        else if( (int_keys & INT_KEY_LEFT) != 0)
        {
            curr_pos++;
            if( curr_pos == 8 )
            {
                curr_pos = 0;
            }
        }
        else if( (int_keys & INT_KEY_RIGHT) != 0)
        {
            curr_pos--;
            if( curr_pos == -1 )
            {
                curr_pos = 7;
            }
        }
        else if( (int_keys & INT_KEY_ENTER) != 0)
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
    const char * space_3       = "   ";
    const char * name_string   = "NAME : ";
    const char * value_string  = "VALUE: ";
    const char * space_20      = "                    ";
    
    CLEAR_LCD;
    
    PRINT_LCD(space_3);
    PRINT_LCD(name_string);
    PRINT_LCD(my_value->name);
    finish_line( 3 + str_len(name_string) + str_len(my_value->name));
    
    PRINT_LCD(space_20);
    
    PRINT_LCD(space_3);
    PRINT_LCD(value_string);
    print_int_hex( *(my_value->addr) );
    finish_line( 3 + str_len(value_string) + 8);
    
    PRINT_LCD(space_20);

    INTERRUPT_MASK = INT_KEY_BACK;
    WFI;
    KEY_ACK;
}

static void do_menu( void * arg )
{
    const struct menu * my_menu = (const struct menu *)arg;
    int curr_index      = 0;
    int last_index      = my_menu->list_size - 1;
    int min_dis_index   = 0;
    int max_dis_index   = 2;
    unsigned short int_keys;
    
    const char * space_20 = "                    ";
    const char * space_3  = "   ";
    const char * arrow    = " X ";
    
    CLEAR_LCD;
    
    while( 1 )
    {
        PRINT_LCD(space_3);
        PRINT_LCD(my_menu->title);
        finish_line( 3 + str_len(my_menu->title) );
        
        for( int i = min_dis_index; i <= max_dis_index; i++)
        {
            if( i > last_index )
            {
                PRINT_LCD(space_20);
            }
            else
            {
                if( i == curr_index )
                {
                    PRINT_LCD(arrow);
                }
                else
                {
                    PRINT_LCD(space_3);
                }
                
                PRINT_LCD(my_menu->list[i].string);
                finish_line( 3 + str_len(my_menu->list[i].string) );
            }
        }
        
        INTERRUPT_MASK = INT_KEY_DOWN | INT_KEY_UP | INT_KEY_ENTER | INT_KEY_BACK;
        WFI;
        
        int_keys = INTERRUPT_PEND;
        KEY_ACK;
        
        if(      (int_keys & INT_KEY_DOWN ) != 0 )
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
        else if( (int_keys & INT_KEY_UP   ) != 0)
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
        else if( (int_keys & INT_KEY_ENTER) != 0)
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
    char volatile top_animation[4][21];
    char * side_animation[4];
    
    char * blank_18 = "                  ";
    char * blank_4  = "    ";
    char * blank_3  = "   ";
    
    char * welcome_message = "STARTING UP";
    
    char solid = 'X';
    char blank = ' ';
    
    side_animation[0] = "X";
    side_animation[1] = "X";
    side_animation[2] = "X";
    side_animation[3] = " ";
    
    for( int i = 0; i < 20; i++ )
    {
        top_animation[0][i] = solid;
        top_animation[1][i] = solid;
        top_animation[2][i] = solid;
        top_animation[3][i] = solid;
        if( (i     % 4) == 0 ){ top_animation[0][i] = blank; }
        if( ((i+1) % 4) == 0 ){ top_animation[1][i] = blank; }
        if( ((i+2) % 4) == 0 ){ top_animation[2][i] = blank; }
        if( ((i+3) % 4) == 0 ){ top_animation[3][i] = blank; }
    }
    
    top_animation[0][20] = 0;
    top_animation[1][20] = 0;
    top_animation[2][20] = 0;
    top_animation[3][20] = 0;
    
    CLEAR_LCD;
    INTERRUPT_MASK = INT_M_TIME;
    M_TIME_CMP = 500;

    int top_pos = 0;
    int bot_pos = 1;
    int side_0  = 0;
    int side_1  = 3;
    int side_2  = 1;
    int side_3  = 2;
    
    for( int i = 0; i < 8; i++ )
    {
        M_TIME_RESET;
                
        PRINT_LCD(&top_animation[top_pos][0]);
        PRINT_LCD(side_animation[side_0]);
        PRINT_LCD(blank_3);
        PRINT_LCD(welcome_message);
        PRINT_LCD(blank_4);
        PRINT_LCD(side_animation[side_1]);
        PRINT_LCD(side_animation[side_2]);
        PRINT_LCD(blank_18);
        PRINT_LCD(side_animation[side_3]);
        PRINT_LCD(&top_animation[bot_pos][0]);
        
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
        
        WFI;
    }
}

void start( void )
{
    my_val_ram1 = 0;
    my_val_ram2 = 0x12345678;
    
    print_start();
    
    while( 1 )
    {
        do_menu((void*)&main_menu);
    }
}
