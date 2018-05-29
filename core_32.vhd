library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library config;
use work.config.all;

entity core_32 is
    Port(
        status  : out std_logic;
        hb      : in  std_logic;
        
        clk     : in std_logic;
        rst     : in std_logic;
        
        interrupt   : in std_logic_vector(10 downto 0);
        
        debounce_done   : out  std_logic;
        debounce_ack    : in   std_logic;

        mem_address     : out std_logic_vector(13 downto 0);
        mem_data_in     : out std_logic_vector( 7 downto 0);
        mem_data_out    : in  std_logic_vector( 7 downto 0);
        mem_write       : out std_logic;
        mem_done        : in  std_logic;
        mem_valid       : out std_logic
    );
end core_32;

architecture Behavioral of core_32 is

-- High-level states of operation (distinct from  modes)
type state is ( INIT, FETCH_A, FETCH_B, FETCH_C, FETCH_D, DECODE_A, DECODE_B, BAD_INSTR, MEM_A, MEM_B, MEM_C,
                REG_SELECT, WRITE_BACK, FINISH_UP,
                ADDI4SPN, LW, LW_B, LW_C, LW_D, LW_E, SW, SW_B, SW_C, SW_D, ADDI, JAL, LI,
                ADDI16SP, LUI, AUIPC, SRLI, SRAI, ANDI, ORI, XORI, SUB, AND_INSTR, OR_INSTR, XOR_INSTR,
                JUMP, BEQZ, BNEZ, SLLI, ADD, MV, JR, JALR,
                BEQ, BNE, BLT, BGE, BLTU, BGEU, SLTI, SLTIU, SLT, SLTU,
                TIME_CONTROL, LCD_CONTROL, LCD_REQUEST, INTERRUPT_CONTROL, WFI, DEBOUNCE
);
signal curr_state, mem_ret_state, reg_sel_ret_state : state;

signal s_interrupt      : std_logic_vector(11 downto 0);
signal s_interrupt_mask : std_logic_vector(11 downto 0);
-- Normal registers --
type regfile_arr is array (0 to 31) of std_logic_vector(31 downto 0);
signal reg: regfile_arr;

signal pc           : std_logic_vector(31 downto 0);
signal s_PC_next    : std_logic_vector(31 downto 0);

signal instr_low        : std_logic_vector( 7 downto 0);
signal instr_med        : std_logic_vector( 7 downto 0);
signal instr_high       : std_logic_vector( 7 downto 0);
signal mem_ret_data     : std_logic_vector( 7 downto 0);
signal s_mem_address    : std_logic_vector(31 downto 0);
signal s_lcd_address    : std_logic_vector(13 downto 0);
signal s_mem_data_in    : std_logic_vector( 7 downto 0);
signal s_mem_write      : std_logic;

-- named register signals for debugging
signal reg_zero     : std_logic_vector(31 downto 0);
signal reg_ra       : std_logic_vector(31 downto 0);
signal reg_sp       : std_logic_vector(31 downto 0);
signal reg_gp       : std_logic_vector(31 downto 0);
signal reg_tp       : std_logic_vector(31 downto 0);
signal reg_t0       : std_logic_vector(31 downto 0);
signal reg_t1       : std_logic_vector(31 downto 0);
signal reg_t2       : std_logic_vector(31 downto 0);
signal reg_s0_fp    : std_logic_vector(31 downto 0);
signal reg_s1       : std_logic_vector(31 downto 0);
signal reg_a0       : std_logic_vector(31 downto 0);
signal reg_a1       : std_logic_vector(31 downto 0);
signal reg_a2       : std_logic_vector(31 downto 0);
signal reg_a3       : std_logic_vector(31 downto 0);
signal reg_a4       : std_logic_vector(31 downto 0);
signal reg_a5       : std_logic_vector(31 downto 0);
signal reg_a6       : std_logic_vector(31 downto 0);
signal reg_a7       : std_logic_vector(31 downto 0);
signal reg_s2       : std_logic_vector(31 downto 0);
signal reg_s3       : std_logic_vector(31 downto 0);
signal reg_s4       : std_logic_vector(31 downto 0);
signal reg_s5       : std_logic_vector(31 downto 0);
signal reg_s6       : std_logic_vector(31 downto 0);
signal reg_s7       : std_logic_vector(31 downto 0);
signal reg_s8       : std_logic_vector(31 downto 0);
signal reg_s9       : std_logic_vector(31 downto 0);
signal reg_s10      : std_logic_vector(31 downto 0);
signal reg_s11      : std_logic_vector(31 downto 0);
signal reg_t3       : std_logic_vector(31 downto 0);
signal reg_t4       : std_logic_vector(31 downto 0);
signal reg_t5       : std_logic_vector(31 downto 0);
signal reg_t6       : std_logic_vector(31 downto 0);

signal m_time_low   : std_logic_vector(15 downto 0);
signal m_time_msec  : std_logic_vector(15 downto 0);
signal m_time_cmp   : std_logic_vector(15 downto 0);

signal imm          : std_logic_vector(31 downto 0);
signal rs1          : integer;
signal rs2          : integer;
signal rd           : integer;

signal s_mem_num_bytes : std_logic_vector(1 downto 0);
signal s_mem_signed    : std_logic;

signal result       : std_logic_vector(31 downto 0);
signal mem_base     : std_logic_vector(31 downto 0);
signal mem_data     : std_logic_vector(31 downto 0);
signal alu_A        : std_logic_vector(31 downto 0);
signal alu_B        : std_logic_vector(31 downto 0);
signal alu_C        : std_logic_vector(31 downto 0);
signal alu_S        : std_logic_vector(31 downto 0);
signal shift_amt    : std_logic_vector(31 downto 0);

begin

s_interrupt(10 downto 0) <= interrupt;
mem_address <= s_mem_address(13 downto 0);
mem_data_in <= s_mem_data_in;
mem_write   <= s_mem_write;

process( clk )
    variable instr : std_logic_vector(31 downto 0);
begin if(rising_edge(clk)) then
    m_time_low      <= m_time_low + 1;
    if( m_time_low = MILLSEC ) then
        m_time_low      <= ZERO_16;
        m_time_msec     <= m_time_msec + 1;
    end if;
    
    if( m_time_msec >= m_time_cmp ) then
        s_interrupt(11)     <= '1';
    else
        s_interrupt(11)     <= '0';
    end if;
    
    case curr_state is
        when INIT =>
            pc          <= ZERO_32;
            s_PC_next   <= ZERO_32;
            
            s_interrupt_mask    <= x"000";
            
            debounce_done   <= '0';
            
            reg <= (others => (others => '0'));
            m_time_low  <= ZERO_16;
            m_time_msec <= ZERO_16;
            m_time_cmp  <= ONES_16;
            
            
            mem_valid   <= '0';
            status      <= '0';
        
        when FETCH_A =>
            s_mem_address   <= pc;
            s_mem_write     <= '0';
            mem_ret_state   <= FETCH_B;
            curr_state      <= MEM_A;
        
        when FETCH_B =>
            instr_low       <= mem_ret_data;
            s_mem_address   <= pc + 1;
            mem_ret_state   <= DECODE_A;
            curr_state      <= MEM_A;
            if( mem_ret_data(1 downto 0) = "11" ) then
                mem_ret_state   <= FETCH_C;
            end if;
        
        when FETCH_C =>
            instr_med       <= mem_ret_data;
            s_mem_address   <= pc + 2;
            mem_ret_state   <= FETCH_D;
            curr_state      <= MEM_A;
        
        when FETCH_D =>
            instr_high      <= mem_ret_data;
            s_mem_address   <= pc + 3;
            mem_ret_state   <= DECODE_B;
            curr_state      <= MEM_A;
        
        when MEM_A =>
            curr_state  <= BAD_INSTR;
            if( s_mem_address(31 downto 17) = ZERO_32(31 downto 17) ) then
                case s_mem_address(16 downto 14) is
                    when "000" =>
                        if ( mem_done = '0' ) then
                            mem_valid   <= '1';
                            curr_state  <= MEM_B;
                        end if;
                    when "001" =>
                        curr_state  <= LCD_CONTROL;
                    when "010" =>
                        curr_state  <= TIME_CONTROL;
                    when "011" =>
                        curr_state  <= INTERRUPT_CONTROL;
                    when "100" =>
                        curr_state  <= DEBOUNCE;
                    when others =>
                end case;
            end if;
                
        
        when MEM_B =>
            if( mem_done = '1' ) then
                curr_state <= MEM_C;
            end if;
        
        when MEM_C =>
            mem_valid       <= '0';
            mem_ret_data    <= mem_data_out;
            curr_state      <= mem_ret_state;
                
        when DECODE_A =>
            instr       := ZERO_16 & mem_ret_data & instr_low;
            curr_state  <= BAD_INSTR;
            s_PC_next   <= pc + 2;
            
            if( instr(12) = '1' ) then
                imm    <= ONES_32(31 downto 6) & instr(12) & instr(6 downto 2);
            else
                imm    <= ZERO_32(31 downto 6) & instr(12) & instr(6 downto 2);
            end if;
            
            case instr(1 downto 0) is
                when "00" =>
                    case instr(15 downto 13) is
                        when "000" =>
                            if( instr /= ZERO_32 ) then
                                imm         <= ZERO_32(31 downto 10) & instr(8 downto 7) & instr(12 downto 9) & instr(5) & instr(6) & "00";
                                rd          <= to_integer(unsigned('1' & instr(4 downto 2)));
                                curr_state  <= ADDI4SPN;
                            end if;
                        
                        when "010" =>
                            imm         <= ZERO_32(31 downto 7) & instr(5) & instr(12 downto 10) & instr(6) & "00";
                            rs1         <= to_integer(unsigned('1' & instr(9 downto 7)));
                            rd          <= to_integer(unsigned('1' & instr(4 downto 2)));
                            s_mem_num_bytes   <= MEM_BYTES_4;
                            curr_state  <= REG_SELECT;
                            reg_sel_ret_state <= LW;
                        
                        when "110" =>
                            imm         <= ZERO_32(31 downto 7) & instr(5) & instr(12 downto 10) & instr(6) & "00";
                            rs1         <= to_integer(unsigned('1' & instr(9 downto 7)));
                            rs2         <= to_integer(unsigned('1' & instr(4 downto 2)));
                            curr_state  <= REG_SELECT;
                            s_mem_num_bytes   <= MEM_BYTES_4;
                            reg_sel_ret_state <= SW;
                        
                        when others =>
                        
                    end case;
                
                when "01" =>
                    case instr(15 downto 13) is
                        when "000" =>
                            if( instr(12 downto 2) /= ZERO_16(12 downto 2) ) then
                                curr_state  <= FINISH_UP;   -- NOP
                            else
                                rs1         <= to_integer(unsigned(instr(11 downto 7)));
                                rd          <= to_integer(unsigned(instr(11 downto 7)));
                                curr_state  <= ADDI;
                            end if;
                        
                        when "001" =>
                            if( instr(12) = '1' ) then
                                imm <= ONES_32(31 downto 12) & instr(12) & instr(5) & instr(10 downto 9)
                                    & instr(11) & instr(7) & instr(8) & instr(4 downto 2) & instr(6) & '0';
                            else
                                imm <= ZERO_32(31 downto 12) & instr(12) & instr(5) & instr(10 downto 9)
                                    & instr(11) & instr(7) & instr(8) & instr(4 downto 2) & instr(6) & '0';
                            end if;
                            rd          <= 1;
                            curr_state  <= JAL;
                        
                        when "010" =>
                            rd                  <= to_integer(unsigned(instr(11 downto 7)));
                            reg_sel_ret_state   <= LI;
                            curr_state          <= REG_SELECT;
                        
                        when "011" =>
                            if( instr(11 downto 7) = "00010" ) then
                                if( instr(12) = '1' ) then
                                    imm <= ONES_32(31 downto 10) & instr(12) & instr(4 downto 3) & instr(5) & instr(2) & instr(6) & "0000";
                                else
                                    imm <= ZERO_32(31 downto 10) & instr(12) & instr(4 downto 3) & instr(5) & instr(2) & instr(6) & "0000";
                                end if;
                                rs1     <= 2;
                                rd      <= 2;
                                reg_sel_ret_state   <= ADDI16SP;
                                curr_state          <= REG_SELECT; 
                            else
                                if( instr(12) = '0' ) then
                                    imm         <= ZERO_32(31 downto 18) & instr(12) & instr(6 downto 2) & ZERO_16(11 downto 0);
                                else
                                    imm         <= ONES_32(31 downto 18) & instr(12) & instr(6 downto 2) & ZERO_16(11 downto 0);
                                end if;
                                rd                  <= to_integer(unsigned(instr(11 downto 7)));
                                reg_sel_ret_state   <= LUI;
                                curr_state          <= REG_SELECT;
                            end if;
                        
                        when "100" =>
                            rd          <= to_integer(unsigned('1' & instr(9 downto 7)));
                            rs1         <= to_integer(unsigned('1' & instr(9 downto 7)));
                            rs2         <= to_integer(unsigned('1' & instr(4 downto 2)));
                            case instr(11 downto 10) is
                                when "00" =>
                                    shift_amt           <= ZERO_32(31 downto 6) & instr(12) & instr(6 downto 2); 
                                    curr_state          <= REG_SELECT;
                                    reg_sel_ret_state   <= SRLI;
                                when "01" =>
                                    shift_amt           <= ZERO_32(31 downto 6) & instr(12) & instr(6 downto 2); 
                                    curr_state          <= REG_SELECT;
                                    reg_sel_ret_state   <= SRAI;
                                when "10" =>
                                    curr_state          <= REG_SELECT;
                                    reg_sel_ret_state   <= ANDI;
                                when "11" =>
                                    if( instr(12) = '0' ) then
                                        case instr(6 downto 5) is
                                            when "00" =>
                                                curr_state          <= REG_SELECT;
                                                reg_sel_ret_state   <= SUB;
                                            when "01" =>
                                                curr_state          <= REG_SELECT;
                                                reg_sel_ret_state   <= XOR_INSTR;
                                            when "10" =>
                                                curr_state          <= REG_SELECT;
                                                reg_sel_ret_state   <= OR_INSTR;
                                            when "11" =>
                                                curr_state          <= REG_SELECT;
                                                reg_sel_ret_state   <= AND_INSTR;
                                            when others =>
                                        end case;
                                    end if;  
                                when others =>
                            end case;
                        
                        when "101" =>
                            if( instr(12) = '1' ) then
                                imm <= ONES_32(31 downto 12) & instr(12) & instr(5) & instr(10 downto 9)
                                    & instr(11) & instr(7) & instr(8) & instr(4 downto 2) & instr(6) & '0';
                            else
                                imm <= ZERO_32(31 downto 12) & instr(12) & instr(5) & instr(10 downto 9)
                                    & instr(11) & instr(7) & instr(8) & instr(4 downto 2) & instr(6) & '0';
                            end if;
                            curr_state  <= JUMP;
                        
                        when "110" =>
                            if( instr(12) = '1' ) then
                                imm <= ONES_32(31 downto 9) & instr(12) & instr(6 downto 5)
                                        & instr(2) & instr(11 downto 10) & instr(4 downto 3) & '0';
                            else
                                imm <= ZERO_32(31 downto 9) & instr(12) & instr(6 downto 5)
                                        & instr(2) & instr(11 downto 10) & instr(4 downto 3) & '0';
                            end if;
                            
                            rs1         <= to_integer(unsigned('1' & instr(9 downto 7)));
                            curr_state  <= REG_SELECT;
                            reg_sel_ret_state   <= BEQZ;
                        
                        when "111" =>
                            if( instr(12) = '1' ) then
                                imm <= ONES_32(31 downto 9) & instr(12) & instr(6 downto 5)
                                        & instr(2) & instr(11 downto 10) & instr(4 downto 3) & '0';
                            else
                                imm <= ZERO_32(31 downto 9) & instr(12) & instr(6 downto 5)
                                        & instr(2) & instr(11 downto 10) & instr(4 downto 3) & '0';
                            end if;
                            
                            rs1         <= to_integer(unsigned('1' & instr(9 downto 7)));
                            curr_state  <= REG_SELECT;
                            reg_sel_ret_state   <= BNEZ;
                            
                        when others =>
                    end case;
                
                when "10" =>
                    rs1         <= to_integer(unsigned(instr(11 downto 7)));
                    rs2         <= to_integer(unsigned(instr( 6 downto 2)));
                    rd          <= to_integer(unsigned(instr(11 downto 7)));
                    
                    case instr(15 downto 13) is
                        when "000" =>
                            shift_amt           <= ZERO_32(31 downto 6) & instr(12) & instr(6 downto 2); 
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= SLLI;
                        
                        when "010" =>
                            imm    <= ZERO_32(31 downto 8) & instr(3 downto 2) & instr(12) & instr(6 downto 4) & "00";
                            rs1     <= 2;
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_4;
                            reg_sel_ret_state   <= LW;
                        
                        when "100" =>
                            if( instr(12) = '0' ) then
                                if( instr(6 downto 2) = "00000" ) then
                                    curr_state          <= REG_SELECT;
                                    imm                 <= ZERO_32;
                                    reg_sel_ret_state   <= JR;
                                else
                                    curr_state          <= REG_SELECT;
                                    reg_sel_ret_state   <= MV;
                                end if;
                            else
                                if( instr(6 downto 2) = "00000" ) then
                                    if( instr(11 downto 7) = "00000" ) then
                                        curr_state  <= FINISH_UP; -- EBREAK ignored
                                    else
                                        rd                  <= 1;
                                        imm                 <= ZERO_32;
                                        curr_state          <= REG_SELECT;
                                        reg_sel_ret_state   <= JALR;
                                    end if;
                                else
                                    curr_state          <= REG_SELECT;
                                    reg_sel_ret_state   <= ADD;
                                end if;
                            end if;
                        
                        when "110" =>
                            imm    <= ZERO_32(31 downto 8) & instr(8 downto 7) & instr(12 downto 9) & "00";
                            rs1     <= 2;
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_4;
                            reg_sel_ret_state   <= SW;
                        
                        when others =>
                    end case;
                
                when others =>
            end case;
        
        when DECODE_B =>
            instr       := mem_ret_data & instr_high & instr_med & instr_low;
            curr_state  <= BAD_INSTR;
            s_PC_next   <= pc + 4;
            
            rd          <= to_integer(unsigned(instr(11 downto 7 )));
            rs1         <= to_integer(unsigned(instr(19 downto 15)));
            rs2         <= to_integer(unsigned(instr(24 downto 20)));
            shift_amt   <= ZERO_32(31 downto 5) & instr(24 downto 20);
            if( instr(31) = '0') then
                imm     <= ZERO_32(31 downto 12) & instr(31 downto 20);
            else
                imm     <= ONES_32(31 downto 12) & instr(31 downto 20);
            end if;
            
            case instr(6 downto 0) is
                when "0110111" =>
                    imm                 <= instr(31 downto 12) & ZERO_32(11 downto 0);
                    curr_state          <= REG_SELECT;
                    reg_sel_ret_state   <= LUI;
                
                when "0010111" =>
                    imm                 <= instr(31 downto 12) & ZERO_32(11 downto 0);
                    curr_state          <= REG_SELECT;
                    reg_sel_ret_state   <= AUIPC;
                
                when "1101111" =>
                    if( instr(31) = '0') then
                        imm     <= ZERO_32(31 downto 21) & instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
                    else
                        imm     <= ONES_32(31 downto 21) & instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
                    end if;
                    curr_state          <= REG_SELECT;
                    reg_sel_ret_state   <= JAL;
                
                when "1100111" =>
                    curr_state          <= REG_SELECT;
                    reg_sel_ret_state   <= JALR;
                
                when "1100011" =>
                    if( instr(31) = '0' ) then
                        imm     <= ZERO_32(31 downto 13) & instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
                    else
                        imm     <= ONES_32(31 downto 13) & instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
                    end if;
                    
                    case instr(14 downto 12) is
                        when "000" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= BEQ;
                        when "001" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= BNE;
                        when "100" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= BLT;
                        when "101" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= BGE;
                        when "110" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= BLTU;
                        when "111" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= BGEU;
                        when others =>
                    end case;
                
                when "0000011" =>
                    case instr(14 downto 12) is
                        when "000" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_1;
                            s_mem_signed        <= '1';
                            reg_sel_ret_state   <= LW;
                        when "001" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_2;
                            s_mem_signed        <= '1';
                            reg_sel_ret_state   <= LW;
                        when "010" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_4;
                            reg_sel_ret_state   <= LW;
                        when "100" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_1;
                            s_mem_signed        <= '0';
                            reg_sel_ret_state   <= LW;
                        when "101" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_2;
                            s_mem_signed        <= '0';
                            reg_sel_ret_state   <= LW;
                        when others =>
                    end case;
                
                when "0100011" =>
                    if( instr(31) = '0' ) then
                        imm     <= ZERO_32(31 downto 12) & instr(31 downto 25) & instr(11 downto 7);
                    else
                        imm     <= ONES_32(31 downto 12) & instr(31 downto 25) & instr(11 downto 7);
                    end if;
                    
                    case instr(14 downto 12) is
                        when "000" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_1;
                            reg_sel_ret_state   <= LW;
                        when "001" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_2;
                            reg_sel_ret_state   <= LW;
                        when "010" =>
                            curr_state          <= REG_SELECT;
                            s_mem_num_bytes     <= MEM_BYTES_4;
                            reg_sel_ret_state   <= LW;
                        when others =>
                    end case;
                
                when "0010011" =>
                    case instr(14 downto 12) is
                        when "000" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= ADDI;
                        when "010" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= SLTI;
                        when "011" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= SLTIU;
                        when "100" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= XORI;
                        when "110" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= ORI;
                        when "111" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= ANDI;
                        when "001" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= SLLI;
                        when "101" =>
                            if(    instr(31 downto 25) = "0000000" ) then
                                curr_state          <= REG_SELECT;
                                reg_sel_ret_state   <= SRLI;
                            elsif( instr(31 downto 25) = "0100000" ) then
                                curr_state          <= REG_SELECT;
                                reg_sel_ret_state   <= SRAI;
                            end if;
                        when others =>
                    end case;
                
                when "0110011" =>
                    case instr(14 downto 12) is
                        when "000" =>
                            if(    instr(31 downto 25) = "0000000" ) then
                                curr_state          <= REG_SELECT;
                                reg_sel_ret_state   <= ADD;
                            elsif( instr(31 downto 25) = "0100000" ) then
                                curr_state          <= REG_SELECT;
                                reg_sel_ret_state   <= SUB;
                            end if;
                        when "001" =>
                            curr_state          <= REG_SELECT;
                            shift_amt           <= ZERO_32(31 downto 5) & reg(to_integer(unsigned(instr(24 downto 20))))(4 downto 0);
                            reg_sel_ret_state   <= SLLI;
                        when "010" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= SLT;
                        when "011" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= SLTU;
                        when "100" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= XOR_INSTR;
                        when "101" =>
                            shift_amt           <= ZERO_32(31 downto 5) & reg(to_integer(unsigned(instr(24 downto 20))))(4 downto 0);
                            if(    instr(31 downto 25) = "0000000" ) then
                                curr_state          <= REG_SELECT;
                                reg_sel_ret_state   <= SRLI;
                            elsif( instr(31 downto 25) = "0100000" ) then
                                curr_state          <= REG_SELECT;
                                reg_sel_ret_state   <= SRAI;
                            end if;
                        when "110" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= OR_INSTR;
                        when "111" =>
                            curr_state          <= REG_SELECT;
                            reg_sel_ret_state   <= AND_INSTR;
                        when others =>
                    end case;
                                    
                when others =>
            end case;
            
        
        when REG_SELECT =>
            mem_base    <= reg(rs1);
            mem_data    <= reg(rs2);
            alu_A       <= reg(rs1);
            alu_B       <= reg(rs2);
            alu_C       <= imm;
            alu_S       <= reg(rs1);
            curr_state  <= reg_sel_ret_state;
        
        when BEQ =>
            if( alu_A = alu_B ) then
                s_PC_next   <= pc + alu_C;
            end if;
            curr_state  <= FINISH_UP;
        
        when BNE =>
            if( alu_A /= alu_B ) then
                s_PC_next   <= pc + alu_C;
            end if;
            curr_state  <= FINISH_UP;
        
        when BLT =>
            if( signed(alu_A) < signed(alu_B) ) then
                s_PC_next   <= pc + alu_C;
            end if;
            curr_state  <= FINISH_UP;
        
        when BGE =>
            if( signed(alu_A) >= signed(alu_B) ) then
                s_PC_next   <= pc + alu_C;
            end if;
            curr_state  <= FINISH_UP;
        
        when BLTU =>
            if( alu_A < alu_B ) then
                s_PC_next   <= pc + alu_C;
            end if;
            curr_state  <= FINISH_UP;
        
        when BGEU =>
            if( alu_A >= alu_B ) then
                s_PC_next   <= pc + alu_C;
            end if;
            curr_state  <= FINISH_UP;
        
        when SLT =>
            result  <= ZERO_32;
            if( signed(alu_A) < signed(alu_B) ) then
                result(0)   <= '1';
            end if;
            curr_state  <= WRITE_BACK;
        
        when SLTU =>
            result  <= ZERO_32;
            if( alu_A < alu_B ) then
                result(0)   <= '1';
            end if;
            curr_state  <= WRITE_BACK;
        
        when SLTI =>
            result  <= ZERO_32;
            if( signed(alu_A) < signed(alu_C) ) then
                result(0)   <= '1';
            end if;
            curr_state  <= WRITE_BACK;
        
        when SLTIU =>
            result  <= ZERO_32;
            if( alu_A < alu_C ) then
                result(0)   <= '1';
            end if;
            curr_state  <= WRITE_BACK;
        
        when ADD =>
            result      <= alu_A + alu_B;
            curr_state  <= WRITE_BACK;
        
        when MV =>
            result      <= alu_B;
            curr_state  <= WRITE_BACK;
        
        when JALR =>
            s_PC_next       <= mem_base + ALU_C;
            s_PC_next(0)    <= '0';
            result          <= s_PC_next;
            curr_state      <= WRITE_BACK;
        
        when JR =>
            s_PC_next   <= mem_base;
            curr_state  <= FINISH_UP;
        
        when BEQZ =>
            if( alu_A = ZERO_32 ) then
                s_PC_next   <= pc + alu_C;
            end if;
            
            curr_state  <= FINISH_UP;
        
        when BNEZ =>
            if( alu_A /= ZERO_32 ) then
                s_PC_next   <= pc + alu_C;
            end if;
            
            curr_state  <= FINISH_UP;
        
        when SLLI =>
            if( shift_amt(5 downto 0) = "000000") then
                result      <= alu_S;
                curr_state  <= WRITE_BACK;
            else
                alu_S       <= alu_S(30 downto 0) & '0';
                shift_amt   <= shift_amt - 1;
            end if;
        
        when SRLI =>
            if( shift_amt(5 downto 0) = "000000") then
                result      <= alu_S;
                curr_state  <= WRITE_BACK;
            else
                alu_S       <= '0' & alu_S(31 downto 1);
                shift_amt   <= shift_amt - 1;
            end if;
            
        when SRAI =>
            if( alu_A(31) = '0' ) then
                curr_state  <= SRLI;
            else
                if( shift_amt(5 downto 0) = "000000") then
                    result      <= alu_S;
                    curr_state  <= WRITE_BACK;
                else
                    alu_S       <= '1' & alu_S(31 downto 1);
                    shift_amt   <= shift_amt - 1;
                end if;
            end if;    
            
        when ANDI =>
            result      <= alu_A and alu_C;
            curr_state  <= WRITE_BACK;
        
        when ORI =>
            result      <= alu_A or alu_C;
            curr_state  <= WRITE_BACK;
        
        when XORI =>
            result      <= alu_A xor alu_C;
            curr_state  <= WRITE_BACK;
        
        when SUB =>
            result      <= alu_A - alu_B;
            curr_state  <= WRITE_BACK;
        
        when XOR_INSTR =>
            result      <= alu_A xor alu_B;
            curr_state  <= WRITE_BACK;
        
        when OR_INSTR =>
            result      <= alu_A or alu_B;
            curr_state  <= WRITE_BACK;
        
        when AND_INSTR =>
            result      <= alu_A and alu_B;
            curr_state  <= WRITE_BACK;
        
        when ADDI16SP =>
            result      <= alu_A + alu_C;
            curr_state  <= WRITE_BACK;
        
        when AUIPC =>
            result      <= pc + alu_C;
            curr_state  <= WRITE_BACK;
        
        when LUI =>
            result      <= alu_C;
            curr_state  <= WRITE_BACK;
        
        when LI =>
            result      <= alu_C;
            curr_state  <= WRITE_BACK;
        
        when JUMP =>
            s_PC_next   <= pc + alu_C;
            curr_state  <= FINISH_UP;
        
        when JAL =>
            s_PC_next   <= pc + alu_C;
            result      <= s_PC_next;
            curr_state  <= WRITE_BACK;
        
        when ADDI =>
            result      <= alu_A + alu_C;
            curr_state  <= WRITE_BACK;
        
        when ADDI4SPN =>
            result      <= alu_C + reg(2);
            curr_state  <= WRITE_BACK;
        
        when LW =>
            s_mem_address   <= mem_base + alu_C;
            s_mem_write     <= '0';
            mem_ret_state   <= LW_B;
            curr_state      <= MEM_A;
        
        when LW_B =>
            result(7 downto 0)  <= mem_ret_data;
            if( s_mem_num_bytes /= MEM_BYTES_1 ) then
                s_mem_address       <= s_mem_address + 1;
                mem_ret_state       <= LW_C;
                curr_state          <= MEM_A;
            else
                if( s_mem_signed = '1' and mem_ret_data(7) = '1' ) then
                    result(31 downto 8) <= ONES_32(31 downto 8);
                else
                    result(31 downto 8) <= ZERO_32(31 downto 8);
                end if;
                curr_state          <= WRITE_BACK;
            end if;
        
        when LW_C =>
            result(15 downto 8) <= mem_ret_data;
            if( s_mem_num_bytes = MEM_BYTES_4 ) then
                s_mem_address       <= s_mem_address + 1;
                mem_ret_state       <= LW_D;
                curr_state          <= MEM_A;
            else
                if( s_mem_signed = '1' and mem_ret_data(7) = '1' ) then
                    result(31 downto 16) <= ONES_32(31 downto 16);
                else
                    result(31 downto 16) <= ZERO_32(31 downto 16);
                end if;
                curr_state          <= WRITE_BACK;
            end if;
        
        when LW_D =>
            result(23 downto 16) <= mem_ret_data;
            s_mem_address       <= s_mem_address + 1;
            mem_ret_state       <= LW_E;
            curr_state          <= MEM_A;
        
        when LW_E =>
            result(31 downto 24)    <= mem_ret_data;
            curr_state              <= WRITE_BACK;
        
        when SW =>
            s_mem_address   <= mem_base + alu_C;
            s_mem_data_in   <= mem_data(7 downto 0);
            s_mem_write     <= '1';
            mem_ret_state   <= SW_B;
            curr_state      <= MEM_A;
        
        when SW_B =>
            if( s_mem_num_bytes /= MEM_BYTES_1 ) then
                s_mem_address   <= s_mem_address + 1;
                s_mem_data_in   <= mem_data(15 downto 8);
                mem_ret_state   <= SW_C;
                curr_state      <= MEM_A;
            else
                curr_state      <= FINISH_UP;
            end if;
        
        when SW_C =>
            if( s_mem_num_bytes = MEM_BYTES_4 ) then
                s_mem_address   <= s_mem_address + 1;
                s_mem_data_in   <= mem_data(23 downto 16);
                mem_ret_state   <= SW_D;
                curr_state      <= MEM_A;
            else
                curr_state      <= FINISH_UP;
            end if;
        
        when SW_D =>
            s_mem_address   <= s_mem_address + 1;
            s_mem_data_in   <= mem_data(31 downto 24);
            mem_ret_state   <= FINISH_UP;
            curr_state      <= MEM_A;
        
        when WRITE_BACK =>
            reg(rd)     <= result;
            curr_state  <= FINISH_UP;
        
                
        when BAD_INSTR =>
            -- unsupported instruction solid light
            status <= '1';
        
        when FINISH_UP =>
            reg(0)     <= ZERO_32;
            
            pc <= s_PC_next;
            
            curr_state <= FETCH_A;
        
        when INTERRUPT_CONTROL =>
            curr_state  <= mem_ret_state;
            if( s_mem_write = '1' ) then
                if(    s_mem_address( 7 downto 0) = x"02" ) then
                    s_interrupt_mask( 7 downto 0) <= s_mem_data_in;
                elsif( s_mem_address( 7 downto 0) = x"03" ) then
                    s_interrupt_mask(11 downto 8) <= s_mem_data_in(3 downto 0);
                elsif( s_mem_address(7 downto 0) = x"04" ) then
                    curr_state <= WFI;
                else
                    curr_state <= BAD_INSTR;
                end if;
            else
                if(    s_mem_address(7 downto 0) = x"00" ) then
                    mem_ret_data    <= s_interrupt(7 downto 0) and s_interrupt_mask( 7 downto 0);
                elsif( s_mem_address(7 downto 0) = x"01" ) then
                    mem_ret_data    <= "0000" & (s_interrupt(11 downto 8) and s_interrupt_mask(11 downto 8));
                elsif( s_mem_address(7 downto 0) = x"02" ) then
                    mem_ret_data    <= s_interrupt_mask( 7 downto 0);
                elsif( s_mem_address(7 downto 0) = x"03" ) then
                    mem_ret_data    <= "0000" & s_interrupt_mask(11 downto 8);
                else
                    curr_state <= BAD_INSTR;
                end if;
            end if;
        
        when WFI =>
            if( ( s_interrupt and s_interrupt_mask ) /= ZERO_16(11 downto 0) ) then
                curr_state <= FINISH_UP;
            end if;
        
        when TIME_CONTROL =>
            curr_state  <= mem_ret_state;
            if( s_mem_write = '0' ) then
                curr_state <= BAD_INSTR;
            else
                if(    s_mem_address(7 downto 0) = x"00" ) then
                    m_time_cmp( 7 downto 0)  <= s_mem_data_in;
                elsif( s_mem_address(7 downto 0) = x"01" ) then
                    m_time_cmp(15 downto 8)  <= s_mem_data_in;
                elsif( s_mem_address(7 downto 0) = x"02" ) then
                    m_time_low      <= ZERO_16;
                    m_time_msec     <= ZERO_16;
                else
                    curr_state <= BAD_INSTR;
                end if;
            end if;
        
        when LCD_CONTROL =>
            if( s_mem_write = '0' ) then
                curr_state <= BAD_INSTR;
            else
                curr_state  <= LCD_REQUEST;
                if( s_mem_data_in = x"00" ) then
                    s_lcd_address   <= ZERO_16(13 downto 0);
                else
                    s_lcd_address   <= s_mem_address(13 downto 0);
                end if;
            end if;
        
        when LCD_REQUEST =>
            curr_state  <= FINISH_UP;
        
        when DEBOUNCE =>
            debounce_done   <= '1';
            if( debounce_ack = '1' ) then
                debounce_done   <= '0';
                curr_state      <= FINISH_UP;
            end if;
        
        when others =>
            -- bad state, light blinks with heart beat
            status <= hb;
            
    end case;
    
    if('1' = rst) then
        curr_state   <= INIT;
    end if;
end if; end process;


reg_zero        <= reg(0);
reg_ra          <= reg(1);
reg_sp          <= reg(2);
reg_gp          <= reg(3);
reg_tp          <= reg(4);
reg_t0          <= reg(5);
reg_t1          <= reg(6);
reg_t2          <= reg(7);
reg_s0_fp       <= reg(8);
reg_s1          <= reg(9);
reg_a0          <= reg(10);
reg_a1          <= reg(11);
reg_a2          <= reg(12);
reg_a3          <= reg(13);
reg_a4          <= reg(14);
reg_a5          <= reg(15);
reg_a6          <= reg(16);
reg_a7          <= reg(17);
reg_s2          <= reg(18);
reg_s3          <= reg(19);
reg_s4          <= reg(20);
reg_s5          <= reg(21);
reg_s6          <= reg(22);
reg_s7          <= reg(23);
reg_s8          <= reg(24);
reg_s9          <= reg(25);
reg_s10         <= reg(26);
reg_s11         <= reg(27);
reg_t3          <= reg(28);
reg_t4          <= reg(29);
reg_t5          <= reg(30);
reg_t6          <= reg(31);

end Behavioral;