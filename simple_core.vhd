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
end core_32;

architecture Behavioral of core_32 is

component stub_ram_0 is
    Port ( 
        address     : in STD_LOGIC_VECTOR (11 downto 0);
        clock       : in STD_LOGIC;
        we          : in STD_LOGIC;
        dataIn      : in STD_LOGIC_VECTOR (7 downto 0);
        dataOut     : out STD_LOGIC_VECTOR (7 downto 0));
end component;

component stub_ram_1 is
    Port ( 
        address     : in STD_LOGIC_VECTOR (11 downto 0);
        clock       : in STD_LOGIC;
        we          : in STD_LOGIC;
        dataIn      : in STD_LOGIC_VECTOR (7 downto 0);
        dataOut     : out STD_LOGIC_VECTOR (7 downto 0));
end component;

component stub_ram_2 is
    Port ( 
        address     : in STD_LOGIC_VECTOR (11 downto 0);
        clock       : in STD_LOGIC;
        we          : in STD_LOGIC;
        dataIn      : in STD_LOGIC_VECTOR (7 downto 0);
        dataOut     : out STD_LOGIC_VECTOR (7 downto 0));
end component;

component stub_ram_3 is
    Port ( 
        address     : in STD_LOGIC_VECTOR (11 downto 0);
        clock       : in STD_LOGIC;
        we          : in STD_LOGIC;
        dataIn      : in STD_LOGIC_VECTOR (7 downto 0);
        dataOut     : out STD_LOGIC_VECTOR (7 downto 0));
end component;

type state is ( INIT, FETCH_CLK, FETCH_WAIT, DECODE, ALU, WRITE_BACK, BRANCH, JUMP, BAD_INSTR,
                MEM_SET, MEM_CLK, MEM_WAIT, MEM_DONE,
                SLL_16, SLL_8, SLL_4, SLL_2, SLL_1,
                SRL_16, SRL_8, SRL_4, SRL_2, SRL_1,
                SRA_16, SRA_8, SRA_4, SRA_2, SRA_1,
                LCD_CONTROL, INTERRUPT_CONTROL, DEBOUNCE_CONTROL_A, DEBOUNCE_CONTROL_B,
                TIME_CONTROL, TIME_RESET_A, TIME_RESET_B, WFI
);
signal curr_state, alu_ret_state : state;

type display_instr is ( NONE, LUI, AUIPC, LB, LH, LW, LBU, LHU, SB, SH, SW, ADDI, JAL, LI,
                SRLI, SRAI, ANDI, ORI, XORI, SUB, AND_INSTR, OR_INSTR, XOR_INSTR,
                SLLI, ADD, MV, JALR,
                BEQ, BNE, BLT, BGE, BLTU, BGEU, SLTI, SLTIU, SLT, SLTU
);
signal dis_instr : display_instr;

signal s_interrupt      : std_logic_vector(15 downto 0);
signal s_interrupt_mask : std_logic_vector(15 downto 0);

type regfile_arr is array (0 to 31) of std_logic_vector(31 downto 0);
signal reg: regfile_arr := (others => (others => '0'));

signal pc           : std_logic_vector(31 downto 0);
signal s_PC_4       : std_logic_vector(31 downto 0);

signal s_mem_address    : std_logic_vector(31 downto 0);
signal s_mem_clk        : std_logic := '0';
signal s_mem_write      : std_logic_vector(3 downto 0) := "0000";
signal s_mem_data_in    : std_logic_vector(31 downto 0);
signal s_mem_data_out   : std_logic_vector(31 downto 0);

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

signal rd           : integer;

signal s_mem_num_bytes : std_logic_vector(1 downto 0);
signal s_mem_signed    : std_logic;
signal s_mem_w         : std_logic;


type alu_cmd_type is ( ALU_ADD, ALU_SUB, ALU_OR, ALU_XOR, ALU_AND,
                       ALU_SEQ, ALU_SNE, ALU_SLT, ALU_SGE, ALU_SLTU, ALU_SGEU
);
signal alu_cmd : alu_cmd_type;
signal alu_a        : std_logic_vector(31 downto 0);
signal alu_b        : std_logic_vector(31 downto 0);
signal result       : std_logic_vector(31 downto 0);

signal shift_amt    : std_logic_vector(4 downto 0);
signal branch_off   : std_logic_vector(31 downto 0);

begin

s_interrupt <= interrupt;

MEM_0 : stub_ram_0
        port map ( address  => s_mem_address(13 downto 2),
                   clock    => s_mem_clk,
                   we       => s_mem_write(0),
                   dataIn   => s_mem_data_in(7 downto 0),
                   dataOut  => s_mem_data_out(7 downto 0)
        );
MEM_1 : stub_ram_1
        port map ( address  => s_mem_address(13 downto 2),
                   clock    => s_mem_clk,
                   we       => s_mem_write(1),
                   dataIn   => s_mem_data_in(15 downto 8),
                   dataOut  => s_mem_data_out(15 downto 8)
        );
MEM_2 : stub_ram_2
        port map ( address  => s_mem_address(13 downto 2),
                   clock    => s_mem_clk,
                   we       => s_mem_write(2),
                   dataIn   => s_mem_data_in(23 downto 16),
                   dataOut  => s_mem_data_out(23 downto 16)
        );
MEM_3 : stub_ram_3
        port map ( address  => s_mem_address(13 downto 2),
                   clock    => s_mem_clk,
                   we       => s_mem_write(3),
                   dataIn   => s_mem_data_in(31 downto 24),
                   dataOut  => s_mem_data_out(31 downto 24)
        );

process( clk )
    variable v_curr_state : state;
    variable instr  : std_logic_vector(31 downto 0);
    variable rs1    : std_logic_vector(31 downto 0);
    variable rs2    : std_logic_vector(31 downto 0);
    variable imm    : std_logic_vector(31 downto 0);
begin if(rising_edge(clk)) then

    if('1' = rst) then
        curr_state   <= INIT;
        dis_instr    <= NONE;
        v_curr_state := INIT;
    else
        v_curr_state := curr_state;
    end if;
    
    case v_curr_state is
        when INIT =>
            pc          <= ZERO_32;
            
            s_interrupt_mask    <= ZERO_16;
            
            debounce_done   <= '0';
 
            status      <= '0';
            
            m_time_cmp      <= ONES_16;
            m_time_reset    <= '0';
            lcd_rs          <= '0';
            lcd_rw          <= '0';
            lcd_e           <= '0';
            lcd_data        <= ZERO_8;
            
            s_mem_address   <= ZERO_32;
            s_mem_write     <= "0000";
            s_mem_clk       <= '0';
            
            curr_state      <= FETCH_CLK;
        
        when FETCH_CLK =>
            s_mem_clk       <= '1';
            curr_state      <= FETCH_WAIT;
        
        when FETCH_WAIT =>
            reg(0)          <= ZERO_32;
            curr_state      <= DECODE;
        
        when DECODE =>
            instr       := s_mem_data_out;
            curr_state  <= BAD_INSTR;
            s_PC_4      <= pc + 4;
            s_mem_clk   <= '0';
            
            rd          <= to_integer(unsigned(instr(11 downto 7 )));
            rs1         := reg(to_integer(unsigned(instr(19 downto 15))));
            rs2         := reg(to_integer(unsigned(instr(24 downto 20))));
            shift_amt   <= instr(24 downto 20);
            if( instr(31) = '0') then
                imm     := ZERO_32(31 downto 12) & instr(31 downto 20);
            else
                imm     := ONES_32(31 downto 12) & instr(31 downto 20);
            end if;
            
            case instr(6 downto 0) is
                when "0110111" =>
                    imm             := instr(31 downto 12) & ZERO_32(11 downto 0);
                    alu_a           <= imm;
                    alu_b           <= ZERO_32;
                    alu_cmd         <= ALU_ADD;
                    alu_ret_state   <= WRITE_BACK;
                    curr_state      <= ALU;
                    dis_instr       <= LUI;
                
                when "0010111" =>
                    imm             := instr(31 downto 12) & ZERO_32(11 downto 0);
                    alu_a           <= imm;
                    alu_b           <= pc;
                    alu_cmd         <= ALU_ADD;
                    alu_ret_state   <= WRITE_BACK;
                    curr_state      <= ALU;
                    dis_instr       <= AUIPC;
                
                when "1101111" =>
                    if( instr(31) = '0') then
                        imm     := ZERO_32(31 downto 21) & instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
                    else
                        imm     := ONES_32(31 downto 21) & instr(31) & instr(19 downto 12) & instr(20) & instr(30 downto 21) & '0';
                    end if;
                    alu_a           <= pc;
                    alu_b           <= imm;
                    alu_cmd         <= ALU_ADD;
                    alu_ret_state   <= JUMP;
                    curr_state      <= ALU;
                    dis_instr       <= JAL;
                
                when "1100111" =>
                    alu_a           <= rs1;
                    alu_b           <= imm;
                    alu_cmd         <= ALU_ADD;
                    alu_ret_state   <= JUMP;
                    curr_state      <= ALU;
                    dis_instr       <= JALR;
                
                when "1100011" =>
                    if( instr(31) = '0' ) then
                        imm     := ZERO_32(31 downto 13) & instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
                    else
                        imm     := ONES_32(31 downto 13) & instr(31) & instr(7) & instr(30 downto 25) & instr(11 downto 8) & '0';
                    end if;
                    
                    alu_a           <= rs1;
                    alu_b           <= rs2;
                    alu_ret_state   <= BRANCH;
                    branch_off      <= imm;
                    
                    case instr(14 downto 12) is
                        when "000" =>
                            alu_cmd         <= ALU_SEQ;
                            curr_state      <= ALU;
                            dis_instr       <= BEQ;
                        when "001" =>
                            alu_cmd         <= ALU_SNE;
                            curr_state      <= ALU;
                            dis_instr       <= BNE;
                        when "100" =>
                            alu_cmd         <= ALU_SLT;
                            curr_state      <= ALU;
                            dis_instr       <= BLT;
                        when "101" =>
                            alu_cmd         <= ALU_SGE;
                            curr_state      <= ALU;
                            dis_instr       <= BGE;
                        when "110" =>
                            alu_cmd         <= ALU_SLTU;
                            curr_state      <= ALU;
                            dis_instr       <= BLTU;
                        when "111" =>
                            alu_cmd         <= ALU_SGEU;
                            curr_state      <= ALU;
                            dis_instr       <= BGEU;
                        when others =>
                    end case;
                
                when "0000011" =>
                    alu_a           <= rs1;
                    alu_b           <= imm;
                    alu_cmd         <= ALU_ADD;
                    alu_ret_state   <= MEM_SET;
                    s_mem_w         <= '0';
                    case instr(14 downto 12) is
                        when "000" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_1;
                            s_mem_signed        <= '1';
                            dis_instr           <= LB;
                        when "001" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_2;
                            s_mem_signed        <= '1';
                            dis_instr           <= LH;
                        when "010" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_4;
                            dis_instr           <= LW;
                        when "100" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_1;
                            s_mem_signed        <= '0';
                            dis_instr           <= LBU;
                        when "101" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_2;
                            s_mem_signed        <= '0';
                            dis_instr           <= LHU;
                        when others =>
                    end case;
                
                when "0100011" =>
                    if( instr(31) = '0' ) then
                        imm     := ZERO_32(31 downto 12) & instr(31 downto 25) & instr(11 downto 7);
                    else
                        imm     := ONES_32(31 downto 12) & instr(31 downto 25) & instr(11 downto 7);
                    end if;
                    
                    alu_a           <= rs1;
                    alu_b           <= imm;
                    alu_cmd         <= ALU_ADD;
                    alu_ret_state   <= MEM_SET;
                    s_mem_w         <= '1';
                    
                    case instr(14 downto 12) is
                        when "000" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_1;
                            dis_instr           <= SB;
                        when "001" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_2;
                            dis_instr           <= SH;
                        when "010" =>
                            curr_state          <= ALU;
                            s_mem_num_bytes     <= MEM_BYTES_4;
                            dis_instr           <= SW;
                        when others =>
                    end case;
                
                when "0010011" =>
                    alu_a           <= rs1;
                    alu_b           <= imm;
                    alu_ret_state   <= WRITE_BACK;
                    case instr(14 downto 12) is
                        when "000" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_ADD;
                            dis_instr       <= ADDI;
                        when "010" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_SLT;
                            dis_instr       <= SLTI;
                        when "011" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_SLTU;
                            dis_instr       <= SLTIU;
                        when "100" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_XOR;
                            dis_instr       <= XORI;
                        when "110" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_OR;
                            dis_instr       <= ORI;
                        when "111" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_AND;
                            dis_instr       <= ANDI;
                        when "001" =>
                            curr_state      <= SLL_16;
                            dis_instr       <= SLLI;
                        when "101" =>
                            if(    instr(31 downto 25) = "0000000" ) then
                                curr_state      <= SRL_16;
                                dis_instr       <= SRLI;
                            elsif( instr(31 downto 25) = "0100000" ) then
                                curr_state      <= SRA_16;
                                dis_instr       <= SRAI;
                            end if;
                        when others =>
                    end case;
                
                when "0110011" =>
                    alu_a           <= rs1;
                    alu_b           <= rs2;
                    alu_ret_state   <= WRITE_BACK;
                    case instr(14 downto 12) is
                        when "000" =>
                            if(    instr(31 downto 25) = "0000000" ) then
                                curr_state      <= ALU;
                                alu_cmd         <= ALU_ADD;
                                dis_instr       <= ADD;
                            elsif( instr(31 downto 25) = "0100000" ) then
                                curr_state      <= ALU;
                                alu_cmd         <= ALU_SUB;
                                dis_instr       <= SUB;
                            end if;
                        when "001" =>
                            curr_state      <= SLL_16;
                            shift_amt       <= reg(to_integer(unsigned(instr(24 downto 20))))(4 downto 0);
                            dis_instr       <= SLLI;
                        when "010" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_SLT;
                            dis_instr       <= SLT;
                        when "011" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_SLTU;
                            dis_instr       <= SLTU;
                        when "100" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_XOR;
                            dis_instr       <= XOR_INSTR;
                        when "101" =>
                            shift_amt           <= reg(to_integer(unsigned(instr(24 downto 20))))(4 downto 0);
                            if(    instr(31 downto 25) = "0000000" ) then
                                curr_state      <= SRL_16;
                                dis_instr       <= SRLI;
                            elsif( instr(31 downto 25) = "0100000" ) then
                                curr_state      <= SRA_16;
                                dis_instr       <= SRAI;
                            end if;
                        when "110" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_OR;
                            dis_instr       <= OR_INSTR;
                        when "111" =>
                            curr_state      <= ALU;
                            alu_cmd         <= ALU_AND;
                            dis_instr       <= AND_INSTR;
                        when others =>
                    end case;
                                    
                when others =>
            end case;
        
        
        when ALU =>
            curr_state      <= alu_ret_state;
            result          <= ZERO_32;
            case alu_cmd is
                when ALU_ADD => result  <= alu_a  +  alu_b;
                when ALU_SUB => result  <= alu_a  -  alu_b;
                when ALU_OR  => result  <= alu_a or  alu_b;
                when ALU_XOR => result  <= alu_a xor alu_b;
                when ALU_AND => result  <= alu_a and alu_b;
                when ALU_SEQ =>
                    if( alu_a = alu_b ) then
                        result(0) <= '1';
                    end if;
                when ALU_SNE =>
                    if( alu_a /= alu_b ) then
                        result(0) <= '1';
                    end if;
                when ALU_SLT =>
                    if( signed(alu_a) < signed(alu_b) ) then
                        result(0) <= '1';
                    end if;
                when ALU_SGE =>
                    if( signed(alu_a) >= signed(alu_b) ) then
                        result(0) <= '1';
                    end if;
                when ALU_SLTU =>
                    if( alu_a < alu_b ) then
                        result(0) <= '1';
                    end if;
                when ALU_SGEU =>
                    if( alu_a >= alu_b ) then
                        result(0) <= '1';
                    end if;
                when others =>
                    result <= ZERO_32;
            end case;
        
        when WRITE_BACK =>
            reg(rd) <= result;
            pc      <= s_PC_4;
            
            s_mem_address   <= s_PC_4;
            s_mem_write     <= "0000";
            s_mem_clk       <= '0';
            
            curr_state      <= FETCH_CLK;
        
        when JUMP =>
            pc      <= result(31 downto 1) & '0';
            reg(rd) <= s_PC_4;
            
            s_mem_address   <= result(31 downto 1) & '0';
            s_mem_write     <= "0000";
            s_mem_clk       <= '0';
            
            curr_state      <= FETCH_CLK;
        
        when BRANCH =>
            if( result(0) = '1' ) then
                rd              <= 0;
                alu_a           <= pc;
                alu_b           <= branch_off;
                alu_cmd         <= ALU_ADD;
                alu_ret_state   <= JUMP;
                curr_state      <= ALU;
            else
                pc          <= s_PC_4;
                
                s_mem_address   <= s_PC_4;
                s_mem_write     <= "0000";
                s_mem_clk       <= '0';
                
                curr_state      <= FETCH_CLK;
            end if;
        
        
        when SLL_16 =>
            curr_state  <= SLL_8;
            if( shift_amt(4) = '1') then
                alu_a       <= alu_a(15 downto 0) & ZERO_16;
            end if;
        
        when SLL_8 =>
            curr_state  <= SLL_4;
            if( shift_amt(3) = '1') then
                alu_a       <= alu_a(23 downto 0) & ZERO_8;
            end if;
        
        when SLL_4 =>
            curr_state  <= SLL_2;
            if( shift_amt(2) = '1') then
                alu_a       <= alu_a(27 downto 0) & "0000";
            end if;
        
        when SLL_2 =>
            curr_state  <= SLL_1;
            if( shift_amt(1) = '1') then
                alu_a       <= alu_a(29 downto 0) & "00";
            end if;
        
        when SLL_1 =>
            curr_state  <= WRITE_BACK;
            if( shift_amt(0) = '1') then
                result      <= alu_a(30 downto 0) & '0';
            else
                result      <= alu_a;
            end if;
        
        when SRL_16 =>
            curr_state  <= SRL_8;
            if( shift_amt(4) = '1') then
                alu_a       <= ZERO_16 & alu_a(31 downto 16);
            end if;
        
        when SRL_8 =>
            curr_state  <= SRL_4;
            if( shift_amt(3) = '1') then
                alu_a       <= ZERO_8 & alu_a(31 downto 8);
            end if;
        
        when SRL_4 =>
            curr_state  <= SRL_2;
            if( shift_amt(2) = '1') then
                alu_a       <= "0000" & alu_a(31 downto 4);
            end if;
        
        when SRL_2 =>
            curr_state  <= SRL_1;
            if( shift_amt(1) = '1') then
                alu_a       <= "00" & alu_a(31 downto 2);
            end if;
        
        when SRL_1 =>
            curr_state  <= WRITE_BACK;
            if( shift_amt(0) = '1') then
                result      <= '0' & alu_a(31 downto 1);
            else
                result      <= alu_a;
            end if;
        
        when SRA_16 =>
            if( alu_a(31) = '0' ) then
                curr_state  <= SRL_16;
            else
                curr_state  <= SRA_8;
                if( shift_amt(4) = '1') then
                    alu_a       <= ONES_16 & alu_a(31 downto 16);
                end if;
            end if;
        
        when SRA_8 =>
            curr_state  <= SRA_4;
            if( shift_amt(3) = '1') then
                alu_a       <= ONES_8 & alu_a(31 downto 8);
            end if;
        
        when SRA_4 =>
            curr_state  <= SRA_2;
            if( shift_amt(2) = '1') then
                alu_a       <= "1111" & alu_a(31 downto 4);
            end if;
        
        when SRA_2 =>
            curr_state  <= SRA_1;
            if( shift_amt(1) = '1') then
                alu_a       <= "11" & alu_a(31 downto 2);
            end if;
        
        when SRA_1 =>
            curr_state  <= WRITE_BACK;
            if( shift_amt(0) = '1') then
                result      <= '1' & alu_a(31 downto 1);
            else
                result      <= alu_a;
            end if;
        
        
        when MEM_SET =>
            -- result is the memory address to work on
            curr_state      <= BAD_INSTR;
            if(    result(31) = '1' ) then
                curr_state      <= LCD_CONTROL;
            elsif( result(30) = '1' ) then
                curr_state      <= INTERRUPT_CONTROL;
            elsif( result(29) = '1' ) then
                curr_state      <= TIME_CONTROL;
            elsif( result(28) = '1' ) then
                curr_state      <= DEBOUNCE_CONTROL_A;
            elsif( result(27 downto 14) = ZERO_32(28 downto 14) ) then
                s_mem_address   <= result;
                s_mem_clk       <= '0';
                s_mem_write     <= "0000";
                if( s_mem_w = '1' ) then
                    if( s_mem_num_bytes = MEM_BYTES_1 ) then
                        case result(1 downto 0) is
                            when "00" =>
                                s_mem_data_in( 7 downto  0)   <= rs2(7 downto 0);
                                s_mem_write(0)              <= '1';
                                curr_state      <= MEM_CLK;
                            when "01" =>
                                s_mem_data_in(15 downto  8)   <= rs2(7 downto 0);
                                s_mem_write(1)              <= '1';
                                curr_state      <= MEM_CLK;
                            when "10" =>
                                s_mem_data_in(23 downto 16)   <= rs2(7 downto 0);
                                s_mem_write(2)              <= '1';
                                curr_state      <= MEM_CLK;
                            when others =>
                                s_mem_data_in(31 downto 24)   <= rs2(7 downto 0);
                                s_mem_write(3)              <= '1';
                                curr_state      <= MEM_CLK;
                        end case;
                    elsif( s_mem_num_bytes = MEM_BYTES_2 ) then
                        if( result(1 downto 0) = "00" ) then
                            s_mem_data_in( 15 downto  0)   <= rs2(15 downto 0);
                            s_mem_write(1 downto 0)        <= "11";
                            curr_state      <= MEM_CLK;
                        elsif( result(1 downto 0) = "10" ) then
                            s_mem_data_in( 31 downto 16)   <= rs2(15 downto 0);
                            s_mem_write(3 downto 2)        <= "11";
                            curr_state      <= MEM_CLK;
                        end if;
                    else
                        if( result(1 downto 0) = "00" ) then
                            s_mem_data_in <= rs2;
                            s_mem_write   <= "1111";
                            curr_state      <= MEM_CLK;
                        end if;
                    end if;
                end if;
            end if;
        
        when MEM_CLK =>
            s_mem_clk       <= '1';
            curr_state      <= MEM_WAIT;
        
        when MEM_WAIT =>
            s_mem_clk       <= '0';
            curr_state      <= MEM_DONE;
            
        when MEM_DONE =>
            curr_state      <= BAD_INSTR;
            result          <= ZERO_32;
            
            if( s_mem_w = '1' ) then
                curr_state  <= WRITE_BACK;
                rd          <= 0;
            else
                if( s_mem_num_bytes = MEM_BYTES_1 ) then
                    case result(1 downto 0) is
                        when "00" =>
                            result( 7 downto  0)    <= s_mem_data_out(7 downto 0);
                            result(31 downto  8)    <= ( others => s_mem_data_out(7));
                            curr_state      <= WRITE_BACK;
                        when "01" =>
                            result( 7 downto  0)    <= s_mem_data_out(15 downto 8);
                            result(31 downto  8)    <= ( others => s_mem_data_out(7));
                            curr_state      <= WRITE_BACK;
                        when "10" =>
                            result( 7 downto  0)    <= s_mem_data_out(23 downto 16);
                            result(31 downto  8)    <= ( others => s_mem_data_out(7));
                            curr_state      <= WRITE_BACK;
                        when others =>
                            result( 7 downto  0)    <= s_mem_data_out(31 downto 24);
                            result(31 downto  8)    <= ( others => s_mem_data_out(7));
                            curr_state      <= WRITE_BACK;
                    end case;
                elsif( s_mem_num_bytes = MEM_BYTES_2 ) then
                    if( result(1 downto 0) = "00" ) then
                        result(15 downto  0)    <= s_mem_data_out(15 downto 0);
                        result(31 downto 16)    <= ( others => s_mem_data_out(15));
                        curr_state      <= WRITE_BACK;
                    elsif( result(1 downto 0) = "10" ) then
                        result(15 downto  0)    <= s_mem_data_out(31 downto 16);
                        result(31 downto 16)    <= ( others => s_mem_data_out(15));
                        curr_state      <= WRITE_BACK;
                    end if;
                else
                    if( result(1 downto 0) = "00" ) then
                        result <= s_mem_data_out;
                        curr_state      <= WRITE_BACK;
                    end if;
                end if;
            end if;
        
                
        when BAD_INSTR =>
            -- unsupported instruction solid light
            status <= '1';
        
        
        when INTERRUPT_CONTROL =>
            curr_state  <= WRITE_BACK;
            result      <= ZERO_32;
            if( s_mem_num_bytes = MEM_BYTES_2 ) then
                if( s_mem_w = '1' ) then
                    rd      <= 0;
                    if(    s_mem_address( 7 downto 0) = x"02" ) then
                        s_interrupt_mask <= rs2(15 downto 0);
                    elsif( s_mem_address( 7 downto 0) = x"04" ) then
                        curr_state <= WFI;
                    else
                        curr_state <= BAD_INSTR;
                    end if;
                else
                    if(    s_mem_address(7 downto 0) = x"00" ) then
                        result(15 downto 0)    <= s_interrupt and s_interrupt_mask;
                    elsif( s_mem_address(7 downto 0) = x"02" ) then
                        result(15 downto 0)    <= s_interrupt_mask;
                    else
                        curr_state <= BAD_INSTR;
                    end if;
                end if;
            else
                curr_state <= BAD_INSTR;
            end if;
        
        when WFI =>
            if( ( s_interrupt and s_interrupt_mask ) /= ZERO_16 ) then
                curr_state <= WRITE_BACK;
            end if;
        
        when TIME_CONTROL =>
            curr_state  <= WRITE_BACK;
            result      <= ZERO_32;
            if( s_mem_num_bytes = MEM_BYTES_2 ) then
                if( s_mem_w = '0' ) then
                    curr_state <= BAD_INSTR;
                else
                    rd      <= 0;
                    if(    s_mem_address(7 downto 0) = x"00" ) then
                        m_time_cmp  <= rs2(15 downto 0);
                    elsif( s_mem_address(7 downto 0) = x"02" ) then
                        curr_state <= TIME_RESET_A;
                    else
                        curr_state <= BAD_INSTR;
                    end if;
                end if;
            else
                curr_state <= BAD_INSTR;
            end if;
        
        when TIME_RESET_A =>
            if( m_time_ack = '0' ) then
                m_time_reset        <= '1';
                curr_state          <= TIME_RESET_B;
            end if;
            
        when TIME_RESET_B =>
            if( m_time_ack = '1' ) then
                m_time_reset    <= '0';
                curr_state      <= WRITE_BACK;
            end if;
            
        
        when LCD_CONTROL =>
            curr_state  <= WRITE_BACK;
            result      <= ZERO_32;
            if( s_mem_num_bytes = MEM_BYTES_1 ) then
                if( s_mem_w = '0' ) then
                    curr_state <= BAD_INSTR;
                else
                    rd      <= 0;
                    if(    s_mem_address(7 downto 0) = x"00" ) then
                        lcd_rs      <= rs2(0);
                    elsif( s_mem_address(7 downto 0) = x"01" ) then
                        lcd_rw      <= rs2(0);
                    elsif( s_mem_address(7 downto 0) = x"02" ) then
                        lcd_e       <= rs2(0);
                    elsif( s_mem_address(7 downto 0) = x"03" ) then
                        lcd_data    <= rs2(7 downto 0);
                    else
                        curr_state <= BAD_INSTR;
                    end if;
                end if;
            else
                curr_state <= BAD_INSTR;
            end if;
        
        when DEBOUNCE_CONTROL_A =>
            if( debounce_ack = '0' ) then
                debounce_done   <= '1';
                curr_state      <= DEBOUNCE_CONTROL_B;
            end if;
        
        when DEBOUNCE_CONTROL_B =>
            if( debounce_ack = '1' ) then
                debounce_done   <= '0';
                curr_state      <= WRITE_BACK;
                result      <= ZERO_32;
                rd          <= 0;
            end if;
        
        when others =>
            -- bad state, light blinks with heart beat
            status <= hb;
            
    end case;
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