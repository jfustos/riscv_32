library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.config.all;

entity shell is
    Port(
        clk         : in std_logic;
        rst         : in std_logic;
        status      : out std_logic;
        hb          : in  std_logic;
        
        button      : in std_logic_vector(5 downto 0);
        
        lcd_rs          : out std_logic;
        lcd_rw          : out std_logic;
        lcd_e           : out std_logic;
        lcd_data        : out std_logic_vector(7 downto 0)
    );
end shell;

architecture Behavioral of shell is

--------------------------------------------------------------------------------
-- Components Forward Declarations
--------------------------------------------------------------------------------

component core_32 is
    Port(
        status  : out std_logic;
        hb      : in  std_logic;
        
        clk     : in std_logic;
        rst     : in std_logic;
        
        interrupt   : in std_logic_vector(15 downto 0);
        
        debounce_done   : out std_logic;
        debounce_ack    : in  std_logic;
        
        m_time_cmp      : out std_logic_vector(15 downto 0);
        m_time_reset    : out std_logic;
        m_time_ack      : in  std_logic;
        
        lcd_rs          : out std_logic;
        lcd_rw          : out std_logic;
        lcd_e           : out std_logic;
        lcd_data        : out std_logic_vector(7 downto 0)
    );
end component;

component debouncer is
    Port(
        clk     : in std_logic;
        rst     : in std_logic;

        inputs    : in  std_logic_vector(5 downto 0);
        outputs   : out std_logic_vector(5 downto 0);

        debounce_done   : in   std_logic;
        debounce_ack    : out  std_logic
    );
end component;

component timer is
    Port(
        clk         : in std_logic;
        rst         : in std_logic;
        
        m_time_cmp      : in  std_logic_vector(15 downto 0);
        m_time_reset    : in  std_logic;
        m_time_ack      : out std_logic;
        
        time_int       : out std_logic
    );
end component;

signal s_debounce_done   : std_logic;
signal s_debounce_ack    : std_logic;

signal key_ints         : std_logic_vector(5 downto 0);

signal s_time_int       : std_logic;

signal unused_ints      : std_logic_vector(14 downto 6);

signal s_interrupt      : std_logic_vector(15 downto 0);

signal s_m_time_cmp      : std_logic_vector(15 downto 0);
signal s_m_time_reset    : std_logic;
signal s_m_time_ack      : std_logic;

begin

unused_ints     <= (others => '0');
s_interrupt     <= s_time_int & unused_ints & key_ints;

my_core_32: core_32
    port map(
        status  => status,
        hb      => hb,
        
        clk => clk,
        rst => rst,
        
        interrupt   => s_interrupt,
        
        debounce_done   => s_debounce_done,
        debounce_ack    => s_debounce_ack,
        
        m_time_cmp      => s_m_time_cmp,
        m_time_reset    => s_m_time_reset,
        m_time_ack      => s_m_time_ack,
        
        lcd_rs          => lcd_rs,
        lcd_rw          => lcd_rw,
        lcd_e           => lcd_e,
        lcd_data        => lcd_data
    );
    
debounce: debouncer
    port map(
        clk => clk,
        rst => rst,
    
        inputs    => button,
        outputs   => key_ints,

        debounce_done   => s_debounce_done,
        debounce_ack    => s_debounce_ack
    );

timey: timer
    port map(
        clk => clk,
        rst => rst,
        
        m_time_cmp      => s_m_time_cmp,
        m_time_reset    => s_m_time_reset,
        m_time_ack      => s_m_time_ack,
        
        time_int        => s_time_int
    );

--------------------------------------------------------------------------------
-- Do Work
--------------------------------------------------------------------------------



end Behavioral;
