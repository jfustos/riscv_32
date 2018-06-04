library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library config;
use work.config.all;

entity debouncer is
    Port(
        clk     : in std_logic;
        rst     : in std_logic;

        inputs    : in  std_logic_vector(5 downto 0);
        outputs   : out std_logic_vector(5 downto 0);

        debounce_done   : in   std_logic;
        debounce_ack    : out  std_logic
    );
end debouncer;

architecture Behavioral of debouncer is

-- High-level states of operation (distinct from  modes)
type state is ( INIT, START, CHECK, COUNT, OUTPUT, FINISH );
signal curr_state : state;

signal prev_inputs : std_logic_vector(5 downto 0);
signal curr_active : integer;

signal counter     : std_logic_vector(23 downto 0);

begin

process( clk )
begin if(rising_edge(clk)) then
    prev_inputs <= inputs;

    case curr_state is
        when INIT =>
            outputs         <= "000000";
            debounce_ack    <= '0';
            curr_state      <= START;

        when START =>
            prev_inputs     <= "111111";
            curr_state      <= CHECK;

        when CHECK =>
            counter <= ZERO_24;
            if(    (inputs(0) = '1') and (prev_inputs(0) = '0') ) then
                curr_active <= 0;
                curr_state  <= COUNT;
            elsif( (inputs(1) = '1') and (prev_inputs(1) = '0') ) then
                curr_active <= 1;
                curr_state  <= COUNT;
            elsif( (inputs(2) = '1') and (prev_inputs(2) = '0') ) then
                curr_active <= 2;
                curr_state  <= COUNT;
            elsif( (inputs(3) = '1') and (prev_inputs(3) = '0') ) then
                curr_active <= 3;
                curr_state  <= COUNT;
            elsif( (inputs(4) = '1') and (prev_inputs(4) = '0') ) then
                curr_active <= 4;
                curr_state  <= COUNT;
            elsif( (inputs(5) = '1') and (prev_inputs(5) = '0') ) then
                curr_active <= 5;
                curr_state  <= COUNT;
            end if;
                
        when COUNT =>
            if( inputs(curr_active) = '1' ) then
                if( counter = MILLSEC_30 ) then
                    curr_state  <= OUTPUT;
                else
                    counter     <= counter + 1;
                end if;
            else
                curr_state      <= START;
            end if;

        when OUTPUT =>
            outputs(curr_active)    <= '1';
            if( debounce_done = '1' ) then
                curr_state              <= FINISH;
                outputs(curr_active)    <= '0';
            end if;

        when FINISH =>
            debounce_ack    <= '1';
            if( debounce_done = '0' ) then
                debounce_ack    <= '0';
                curr_state      <= START;
            end if;

        when others =>
    end case;

    if('1' = rst) then
        curr_state   <= INIT;
    end if;
end if; end process;

end Behavioral;