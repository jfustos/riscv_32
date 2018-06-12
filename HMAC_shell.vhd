library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity HMAC_shell is
    Port (
        clk             : in  STD_LOGIC;
        rst             : in  STD_LOGIC;
        
        key             : in  STD_LOGIC_VECTOR (63 downto 0);
        request         : in  STD_LOGIC;
        done            : out STD_LOGIC;
        
        hash_output     : out std_logic_vector(255 downto 0)
    );
end HMAC_shell;

architecture Behavioral of HMAC_shell is
    component HMAC_controller is
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
    end component;
    
    component sha256 is
        port(
            clk    : in std_logic;
            reset  : in std_logic;
            enable : in std_logic;
    
            ready  : out std_logic; -- Ready to process the next block
            update : in  std_logic; -- Start processing the next block
    
            -- Connections to the input buffer; we assume block RAM that presents
            -- valid data the cycle after the address has changed:
            word_address : out std_logic_vector(3 downto 0); -- Word 0 .. 15
            word_input   : in std_logic_vector(31 downto 0);
    
            -- Intermediate/final hash values:
            hash_output : out std_logic_vector(255 downto 0);
    
            -- Debug port, used in simulation; leave unconnected:
            debug_port : out std_logic_vector(31 downto 0)
        );
    end component;
begin


end Behavioral;
