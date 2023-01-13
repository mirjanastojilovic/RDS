-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity read_traces is
generic (
    NUM_SAMPLE      : Positive := 8;
    SAMPLE_WIDTH    : Positive := 8;
    BRAM_ADDR_WIDTH : Positive := 16;
    BRAM_WORD_WIDTH : Positive := 144;
    SENSOR_WIDTH    : Positive := 128
    );
port (
       clk_i            : in  std_logic;
       n_reset_i        : in  std_logic;

       start_i          : in  std_logic;
       sensor_data_i    : in  std_logic_vector(SENSOR_WIDTH-1 downto 0);
       temperature_i_s    : in  STD_LOGIC_VECTOR(11 downto 0);

       en_o             : out std_logic;
       data_o           : out std_logic_vector (BRAM_WORD_WIDTH-1 downto 0);
       addr_o           : out std_logic_vector (BRAM_ADDR_WIDTH-1 downto 0)
       );
end read_traces;

architecture behavioral of read_traces is

    component counter_up is
    generic (
        SIZE    : Positive := 16
    );
    port (
        n_reset_i   : in  std_logic;
        clk_i       : in  std_logic;
        load_i      : in  std_logic; -- prioritized load command --
        up_i        : in  std_logic; -- increment command --
        val_i       : in  std_logic_vector(SIZE-1 downto 0);
        val_o       : out std_logic_vector(SIZE-1 downto 0)
    );
    end component;

    component cdc_reg is
    Port ( clk_wr_i : in STD_LOGIC;
           clk_rd_i : in STD_LOGIC;
           signal_i : in STD_LOGIC;
           signal_o : out STD_LOGIC);
    end component;

    type state_t is (
      IDLE,
      START,
      WRITE_SAMPLES,
      DONE
    );
    constant NUM_SAMPLES                    : std_logic_vector(addr_o'range) := std_logic_vector(to_unsigned(NUM_SAMPLE, BRAM_ADDR_WIDTH) - 1);

    signal curr_state_r                     : state_t;
    signal next_state_s                     : state_t;

     -- counter up
    signal addr_os                          : std_logic_vector(addr_o'range);
    

    signal rd_en_s                          : std_logic;
    signal rd_en_r                          : std_logic;

    signal ld_cntr_s                        : std_logic;

    signal cntr_up_s                        : std_logic;
    signal cntr_up_r                        : std_logic;
    signal cntr_reset_n                     : std_logic;
    signal cntr_reset_s                     : std_logic;

    signal word_os                          : std_logic_vector(data_o'range);
    signal word_or                          : std_logic_vector(data_o'range);
    
    signal  sensor_data_ir              : std_logic_vector(SENSOR_WIDTH-1 downto 0);
    signal temperature_ir                 :std_logic_vector(11 downto 0);
    
    signal  sensor_data_is          : std_logic_vector(SENSOR_WIDTH-1 downto 0);
    signal  temperature_is : std_logic_vector(11 downto 0);

begin
    cntr_reset_s <= n_reset_i and cntr_reset_n;
    

  sensor_data_is      <= sensor_data_i;
  temperature_is      <= temperature_i_s;

  input_delay:process(clk_i) is
  begin
    if rising_edge(clk_i) then
        if n_reset_i = '0' then
            sensor_data_ir      <= (others => '0');
            temperature_ir      <= (others => '0');
        else
            sensor_data_ir      <= sensor_data_is;
            temperature_ir      <= temperature_is;
        end if;
    end if;
  end process;

  state_dec:process(start_i, addr_os, curr_state_r)
  begin
    next_state_s        <= curr_state_r;
    cntr_reset_n        <= '1';
    case curr_state_r is
      when IDLE =>
        if(start_i = '1') then
          next_state_s <= START;
        else
          next_state_s <= IDLE;
        end if;
      when START =>
        next_state_s <= WRITE_SAMPLES;
      when WRITE_SAMPLES =>
        if(addr_os = NUM_SAMPLES) then
          next_state_s <= DONE;
          cntr_reset_n <= '0';
        else
          next_state_s <= WRITE_SAMPLES;
        end if;
      when DONE =>
        next_state_s <= IDLE;
      when others =>
        null;
    end case;
  end process;

  output_dec:process(curr_state_r, sensor_data_ir,temperature_ir)
  begin
    rd_en_s               <= rd_en_r;
    cntr_up_s             <= cntr_up_r;
    ld_cntr_s             <= '0';
    word_os               <= word_or;
    case curr_state_r is
      when IDLE =>
        rd_en_s           <= '0';
        ld_cntr_s         <= '1';        
      when START =>
        rd_en_s                                             <= '1';
        cntr_up_s                                           <= '1';
        word_os(SENSOR_WIDTH-1 downto 0)              <= sensor_data_ir;
        word_os(SENSOR_WIDTH+11 downto SENSOR_WIDTH) <= temperature_ir;
        word_os(BRAM_WORD_WIDTH-1 downto SENSOR_WIDTH+12) <= (others => '0');
        
      when WRITE_SAMPLES =>
         word_os(SENSOR_WIDTH-1 downto 0)              <= sensor_data_ir;
         word_os(SENSOR_WIDTH+11 downto SENSOR_WIDTH) <= temperature_ir;
         word_os(BRAM_WORD_WIDTH-1 downto SENSOR_WIDTH+12) <= (others => '0');

      when DONE =>
         word_os          <= (others => '0');
        ld_cntr_s         <= '1';        
        rd_en_s           <= '0';
        cntr_up_s          <= '0';
    when others =>
        null;
    end case;
  end process;
  
  reg_update:process(clk_i)
  begin
    if(rising_edge(clk_i)) then
        if(n_reset_i = '0') then
            curr_state_r    <= IDLE;
            word_or         <= (others => '0');
            rd_en_r         <= '0';
            cntr_up_r       <= '0';
        else
            curr_state_r    <= next_state_s;
            word_or         <= word_os;
            rd_en_r         <= rd_en_s;
            cntr_up_r       <= cntr_up_s;
        end if;
    end if;
  end process;


cntr: counter_up
    port map (
        n_reset_i   => cntr_reset_s,
        clk_i       => clk_i,
        load_i      => ld_cntr_s,
        up_i        => cntr_up_s,
        val_i       => (others => '0'),
        val_o       => addr_os
    );

    en_o        <= rd_en_s;
    addr_o      <= addr_os;
    data_o      <= word_os;

end behavioral;

