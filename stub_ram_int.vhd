library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity stub_ram_int is
    Port ( memAddress       : in STD_LOGIC_VECTOR (13 downto 0);
           dataIn           : in STD_LOGIC_VECTOR (7 downto 0);
           dataOut          : out STD_LOGIC_VECTOR (7 downto 0);
           valid            : in STD_LOGIC;
           done             : out STD_LOGIC;
           write            : in STD_LOGIC;
           clk, reset       : in STD_LOGIC );
end stub_ram_int;

architecture Behavioral of stub_ram_int is
    component stub_ram
        port( 
              address : in STD_LOGIC_VECTOR (13 downto 0);
              clock : in STD_LOGIC;
              we : in STD_LOGIC;
              dataIn : in STD_LOGIC_VECTOR (7 downto 0);
              dataOut : out STD_LOGIC_VECTOR (7 downto 0));
    end component;
    
    signal s_mem_address    : STD_LOGIC_VECTOR (13 downto 0);
    signal s_data_in        : STD_LOGIC_VECTOR (7 downto 0);
    signal s_mem_clock      : STD_LOGIC;
    signal s_write          : STD_LOGIC;
    signal s_mem_data_out   : STD_LOGIC_VECTOR (7 downto 0);
    
    type memState is ( WAITING, MEM_CLOCK, FINISH );
    signal curr_state : memState;
    
begin
    
    MEM : stub_ram
        port map ( address  => s_mem_address,
                   clock    => s_mem_clock,
                   we       => s_write,
                   dataIn   => s_data_in,
                   dataOut  => s_mem_data_out);
    
    process( clk, reset )
    begin
        if ( reset = '1' ) then
               done <= '0';
               curr_state <= WAITING;
        elsif ( rising_edge( clk ) ) then
            case curr_state is
                when WAITING =>
                    s_mem_clock <= '0';
                    done <= '0';
                    if( valid = '1' ) then
                        s_mem_address <= memAddress;
                        s_data_in  <= dataIn;
                        s_write    <= write;
                        curr_state <= MEM_CLOCK;
                    end if;
                    
                when MEM_CLOCK =>
                        s_mem_clock <= '1';
                        curr_state  <= FINISH;
                    
                when FINISH =>
                        done    <= '1';
                        dataOut <= s_mem_data_out;
                        if( valid = '0' ) then
                            curr_state <= WAITING;
                        end if;
            end case;
        end if;
    end process;

end Behavioral;
