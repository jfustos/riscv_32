library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library config;
use work.config.all;

entity timer is
    Port(
        clk         : in std_logic;
        rst         : in std_logic;
        
        m_time_cmp      : in  std_logic_vector(15 downto 0);
        m_time_reset    : in  std_logic;
        m_time_ack      : out std_logic;
        
        time_int       : out std_logic
    );
end timer;

architecture Behavioral of timer is
    type state is ( INIT, ALU_16, TICK_LOW, CHECK_LOW, TICK_HIGH, CHECK_HIGH, CHECK_RESET, CHECK_INT );
    signal curr_state, alu_ret_state : state;
    
    type alu_cmd_type is ( ALU_ADD, ALU_SGEU
    );
    signal alu_cmd : alu_cmd_type;
    signal alu_a        : std_logic_vector(15 downto 0);
    signal alu_b        : std_logic_vector(15 downto 0);
    signal result       : std_logic_vector(15 downto 0);
    
    signal time_low     : std_logic_vector(15 downto 0);
    signal time_high    : std_logic_vector(15 downto 0);
begin

process( clk )
begin if(rising_edge(clk)) then

    case curr_state is
        when INIT =>
            m_time_ack      <= '0';
            time_int        <= '0';
            
            time_low        <= ZERO_16;
            time_high       <= ZERO_16;
            result          <= ZERO_16;
            
            curr_state      <= TICK_LOW;
        
        when ALU_16 =>
            curr_state  <= alu_ret_state;
            
            result <= ZERO_16;
            case alu_cmd is
                when ALU_ADD => result <= alu_a + alu_b;
                when ALU_SGEU =>
                    if ( alu_a >= alu_b ) then
                        result(0)   <= '1';
                    end if;    
                when others =>
            end case;
        
        when TICK_LOW =>
            alu_a           <= time_low;
            alu_b           <= ZERO_16;
            alu_b(0)         <= '1';
            alu_cmd         <= ALU_ADD;
            alu_ret_state   <= CHECK_LOW;
            curr_state      <= ALU_16;
        
        when CHECK_LOW =>
            time_low        <= result;
            alu_a           <= result;
            alu_b           <= M_SEC_TIMER;
            alu_cmd         <= ALU_SGEU;
            alu_ret_state   <= TICK_HIGH;
            curr_state      <= ALU_16;
        
        when TICK_HIGH =>
            alu_a           <= result;
            alu_b           <= time_high;
            alu_cmd         <= ALU_ADD;
            alu_ret_state   <= CHECK_HIGH;
            curr_state      <= ALU_16;
        
        when CHECK_HIGH =>
            time_high       <= result;
            alu_a           <= result;
            alu_b           <= m_time_cmp;
            alu_cmd         <= ALU_SGEU;
            alu_ret_state   <= TICK_LOW;
            curr_state      <= ALU_16;
        
        when CHECK_RESET =>
            curr_state  <= CHECK_INT;
            if( m_time_reset = '1' ) then
                time_low        <= ZERO_16;
                time_high       <= ZERO_16;
                result          <= ZERO_16;
                m_time_ack      <= '1';
            else
                m_time_ack      <= '0';
                curr_state  <= CHECK_INT;
            end if;
            
        when CHECK_INT =>
            curr_state      <= TICK_LOW;
            
            if( result(0) = '1' ) then
                time_int    <= '1';
            else
                time_int    <= '0';
            end if;
        
        when others =>
    end case;

    if('1' = rst) then
        curr_state   <= INIT;
    end if;
end if; end process;

end Behavioral;
