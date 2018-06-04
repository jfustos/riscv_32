library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity top_sim is
--  Port ( );
end top_sim;

architecture Behavioral of top_sim is
    component shell is
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
    end component;
    
    signal clk         : std_logic;
    signal rst         : std_logic;
    signal status      : std_logic;
    signal hb          : std_logic;
    
    signal button      : std_logic_vector(5 downto 0);
    
    signal lcd_rs          : std_logic;
    signal lcd_rw          : std_logic;
    signal lcd_e           : std_logic;
    signal lcd_data        : std_logic_vector(7 downto 0);
    
begin

my_shell: shell
    port map(
        clk         => clk,
        rst         => rst,
        status      => status,
        hb          => hb,
        
        button      => button,
        
        lcd_rs          => lcd_rs,
        lcd_rw          => lcd_rw,
        lcd_e           => lcd_e,
        lcd_data        => lcd_data
    );

hb      <= clk;
button  <= "000000";

process
begin
    clk     <= '0';
    wait for 5 ns;
    clk     <= '1';
    wait for 5 ns;
end process;

process
begin
    rst     <= '1';
    wait for 15 ns;
    rst     <= '0';
    wait;
end process;

end Behavioral;
