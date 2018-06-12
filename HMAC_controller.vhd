library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity HMAC_controller is
    Port (
        clk             : in  STD_LOGIC;
        rst             : in  STD_LOGIC;
        
        key             : in  STD_LOGIC_VECTOR (63 downto 0);
        request         : in  STD_LOGIC;
        done            : out STD_LOGIC;
        
        data_in         : in  STD_LOGIC_VECTOR (511 downto 0);
        data_ready      : in  STD_LOGIC;
        data_done       : out STD_LOGIC;
        data_complete   : in  STD_LOGIC;
        
        hash_out        : out STD_LOGIC_VECTOR (31 downto 0);
        hash_addr       : in  STD_LOGIC_VECTOR (3 downto 0);
        hash_enable     : out STD_LOGIC;
        hash_update     : out STD_LOGIC;
        hash_ready      : in  STD_LOGIC
    );
end HMAC_controller;

architecture Behavioral of HMAC_controller is
    constant OPAD   : STD_LOGIC_VECTOR (511 downto 0) := x"5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c";
    constant IPAD   : STD_LOGIC_VECTOR (511 downto 0) := x"36363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636";
    
    type state is ( INIT, WAIT_FOR_KEY, KEY_XOR_OPAD, KEY_XOR_IPAD,
                    SEND_HASH, SHAKE_HASH, WAIT_HASH,
                    WAIT_DATA, GET_DATA, FINISH_DATA,
                    WAIT_DONE
    );
    signal curr_state, hash_ret_state : state;
    
    type data_buffer is array (0 to 15) of std_logic_vector(31 downto 0);
    signal s_buffer : data_buffer := (others => (others => '0'));
    
    signal k_prime          : STD_LOGIC_VECTOR (511 downto 0);
    signal s_o_key_pad      : STD_LOGIC_VECTOR (511 downto 0);
    
begin
    
    hash_out        <= s_buffer(to_integer(unsigned(hash_addr)));

process( clk )
    variable v_curr_state : state;    
begin if(rising_edge(clk)) then
    
    if('1' = rst) then
        curr_state   <= INIT;
        v_curr_state := INIT;
    else
        v_curr_state := curr_state;
    end if;
    
    case v_curr_state is
        when INIT =>
            done        <= '0';
            data_done   <= '0';
            hash_update <= '0';
            hash_enable <= '1';
            
            curr_state  <= WAIT_FOR_KEY;
        
        when WAIT_FOR_KEY =>
            if( request = '1' ) then
                k_prime(511 downto 448 )    <= key;
                k_prime(447 downto 0   )    <= ( others => '0' );
                curr_state  <= KEY_XOR_OPAD;
            end if;
        
        when KEY_XOR_OPAD =>
            s_o_key_pad     <= k_prime xor OPAD;
            curr_state      <= KEY_XOR_IPAD;
        
        when KEY_XOR_IPAD =>
            s_buffer( 0)    <= k_prime( 31 downto   0) xor IPAD(31 downto   0);
            s_buffer( 1)    <= k_prime( 63 downto  32) xor IPAD( 63 downto  32);
            s_buffer( 2)    <= k_prime( 95 downto  64) xor IPAD( 95 downto  64);
            s_buffer( 3)    <= k_prime(127 downto  96) xor IPAD(127 downto  96);
            s_buffer( 4)    <= k_prime(159 downto 128) xor IPAD(159 downto 128);
            s_buffer( 5)    <= k_prime(191 downto 160) xor IPAD(191 downto 160);
            s_buffer( 6)    <= k_prime(223 downto 192) xor IPAD(223 downto 192);
            s_buffer( 7)    <= k_prime(255 downto 224) xor IPAD(255 downto 224);
            s_buffer( 8)    <= k_prime(287 downto 256) xor IPAD(287 downto 256);
            s_buffer( 9)    <= k_prime(319 downto 288) xor IPAD(319 downto 288);
            s_buffer(10)    <= k_prime(351 downto 320) xor IPAD(351 downto 320);
            s_buffer(11)    <= k_prime(383 downto 352) xor IPAD(383 downto 352);
            s_buffer(12)    <= k_prime(415 downto 384) xor IPAD(415 downto 384);
            s_buffer(13)    <= k_prime(447 downto 416) xor IPAD(447 downto 416);
            s_buffer(14)    <= k_prime(479 downto 448) xor IPAD(479 downto 448);
            s_buffer(15)    <= k_prime(511 downto 480) xor IPAD(511 downto 480);
            hash_ret_state  <= WAIT_DATA;
            curr_state      <= SEND_HASH;
        
        when SEND_HASH =>
            if( hash_ready = '1' ) then
                hash_update     <= '1';
                curr_state      <= SHAKE_HASH;
            end if;
        
        when SHAKE_HASH =>
            if( hash_ready = '0' ) then
                hash_update     <= '0';
                curr_state      <= WAIT_HASH;
            end if;
        
        when WAIT_HASH =>
            if( hash_ready = '1' ) then
                curr_state      <= hash_ret_state;
            end if;
        
        when WAIT_DATA =>
            if( data_ready = '1' ) then
                curr_state      <= GET_DATA;
            end if;
        
        when GET_DATA =>
            s_buffer( 0)    <= data_in( 31 downto   0);
            s_buffer( 1)    <= data_in( 63 downto  32);
            s_buffer( 2)    <= data_in( 95 downto  64);
            s_buffer( 3)    <= data_in(127 downto  96);
            s_buffer( 4)    <= data_in(159 downto 128);
            s_buffer( 5)    <= data_in(191 downto 160);
            s_buffer( 6)    <= data_in(223 downto 192);
            s_buffer( 7)    <= data_in(255 downto 224);
            s_buffer( 8)    <= data_in(287 downto 256);
            s_buffer( 9)    <= data_in(319 downto 288);
            s_buffer(10)    <= data_in(351 downto 320);
            s_buffer(11)    <= data_in(383 downto 352);
            s_buffer(12)    <= data_in(415 downto 384);
            s_buffer(13)    <= data_in(447 downto 416);
            s_buffer(14)    <= data_in(479 downto 448);
            s_buffer(15)    <= data_in(511 downto 480);
            data_done       <= '1';
            curr_state      <= FINISH_DATA;
        
        when FINISH_DATA =>
            if( data_ready = '0' ) then
                data_done       <= '0';
                hash_ret_state  <= WAIT_DATA;
                curr_state      <= SEND_HASH;
                if( data_complete = '1' ) then
                    hash_ret_state  <= WAIT_DONE;
                end if;
            end if;
        
        when WAIT_DONE =>
            done        <= '1';
            hash_enable <= '0';
        
        when others =>

    end case;
end if; end process;



end Behavioral;
