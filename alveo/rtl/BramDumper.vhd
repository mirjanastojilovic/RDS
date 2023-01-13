-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity BramDumper is
    Generic ( IN_WIDTH        : integer := 8;
              BRAM_DATA_WIDTH : integer := 32;     -- MUST ALWAYS BE A POWER OF TWO
              BRAM_ADDR_WIDTH : integer := 32;     -- MUST ALWAYS BE A POWER OF TWO
              N_SAMPLES       : integer := 1024;   -- MUST ALWAYS BE A POWER OF TWO
              BYTE_ADDR       : integer := 0);     -- Is the BRAM byte addressable or word addressable?
    Port ( clk         : in  STD_LOGIC;
           reset_n     : in  STD_LOGIC;
           clk_en_p_i  : in  STD_LOGIC;
           trigger_p_i : in  STD_LOGIC;
           start_dump  : out STD_LOGIC;
           bram_dump_idle : out STD_LOGIC;
           data_i      : in  STD_LOGIC_VECTOR (IN_WIDTH-1          downto 0);
           data_o      : out STD_LOGIC_VECTOR (BRAM_DATA_WIDTH-1   downto 0);
           waddr_o     : out STD_LOGIC_VECTOR (BRAM_ADDR_WIDTH-1   downto 0);
           strb_o      : out STD_LOGIC_VECTOR (BRAM_DATA_WIDTH/8-1 downto 0);
           wen_o       : out std_logic);
end BramDumper;

architecture Behavioral of BramDumper is

  function logarithm2(n : integer) return integer is
    variable m, p : integer;
  begin
    m := 0;
    p := 1;
    while (p < n) loop
      m := m+1;
      p := p*2;
    end loop;
    return m;
  end logarithm2;

  type CU_states is (IDLE, WRITE, DUMP);
  signal state_reg, state_next: CU_states;

  constant STRB_WIDTH    : integer := BRAM_DATA_WIDTH/8;                    -- the width of the strobe register
  constant STRB_SIZE     : integer := natural(ceil(real(IN_WIDTH)/real(8))); -- the number of set strobe bits per write transaction, 
                                                                            -- i.e. the number of bytes needed to represent the sensor value
                                                                            -- and thus the number of bytes needed to be stored in the BRAM
  constant SHIFT_SIZE    : integer := natural(ceil(real(IN_WIDTH)/real(8))); -- the shift step of the strobe signal for writing the next data 
  constant OFFSET        : integer := logarithm2(BRAM_DATA_WIDTH/8);        -- the offset in the byte addressable address introduced by the BRAM data with
  constant MAX_CNT       : integer := (N_SAMPLES * IN_WIDTH) / BRAM_DATA_WIDTH;                 -- the number to which the counter counts. The counter concatenated with the offset gives the address
  constant MAX_CNT_WIDTH : integer := logarithm2((N_SAMPLES * IN_WIDTH) / BRAM_DATA_WIDTH);     -- the counter word size

  signal shift_en_s, overflow_last_s : std_logic;
  signal strb_q : std_logic_vector(STRB_WIDTH-1 downto 0);
  signal waddr_s : std_logic_vector(MAX_CNT_WIDTH-1 downto 0);
  signal cnt_en_s : std_logic;

begin

  -- state register
  state_proc: process(clk) is
  begin
    if(clk'event and clk='1') then
      if(reset_n = '0') then
        state_reg <= IDLE;
      elsif(clk_en_p_i = '1') then
        state_reg <= state_next;
      end if;
    end if;
  end process;

  -- strb registers
  strb_regs: process(clk) is
  begin
    if(clk'event and clk='1') then
      if(reset_n = '0') then
        strb_q(STRB_SIZE-1 downto 0)          <= (others => '1');
        strb_q(strb_q'left  downto STRB_SIZE) <= (others => '0');
      elsif(clk_en_p_i = '1') then
        if(shift_en_s = '1') then
          strb_q <= std_logic_vector(rotate_left(unsigned(strb_q), SHIFT_SIZE));
        else
          strb_q(STRB_SIZE-1 downto 0)          <= (others => '1');
          strb_q(strb_q'left  downto STRB_SIZE) <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  -- next state logic
  next_state: process(state_reg, trigger_p_i, overflow_last_s, strb_q(strb_q'left)) is
  begin
    case state_reg is
      when IDLE =>
        if(trigger_p_i = '1') then
          state_next <= WRITE;
        else
          state_next <= IDLE;
        end if;
      when WRITE =>
        if(overflow_last_s = '1' and strb_q(strb_q'left) = '1') then
          state_next <= DUMP;
        else
          state_next <= WRITE;
        end if;
      when DUMP =>
        state_next <= IDLE;
    end case;
  end process;

  -- Moore output logic
  output_logic: process(state_reg) is
  begin
    case state_reg is
      when IDLE =>
        shift_en_s <= '0';
        wen_o      <= '0';
        start_dump <= '0';
        bram_dump_idle <= '1';
      when WRITE =>
        shift_en_s <= '1';
        wen_o      <= '1';
        start_dump <= '0';
        bram_dump_idle <= '0';
      when DUMP =>
        shift_en_s <= '0';
        wen_o      <= '0';
        start_dump <= '1';
        bram_dump_idle <= '0';
    end case;
  end process;

  cnt_en_s <=  strb_q(strb_q'left) and shift_en_s;

  address_counter: entity work.counter_simple
  GENERIC MAP ( 
    MAX      => MAX_CNT)
  PORT MAP (
    clk              => clk, 
    clk_en_p         => clk_en_p_i, 
    reset_n          => reset_n, 
    cnt_en           => cnt_en_s, 
    count_o          => waddr_s, 
    overflow_o_p     => open, 
    cnt_next_en_o_p  => overflow_last_s
  );

  data_out_generate: for i in 0 to STRB_WIDTH/STRB_SIZE-1 generate
    data_o(i*8*STRB_SIZE+IN_WIDTH-1 downto i*8*STRB_SIZE)     <= data_i;
    data_o((i+1)*8*STRB_SIZE-1 downto i*8*STRB_SIZE+IN_WIDTH) <= (others => '0');
  end generate data_out_generate;

  byte_addr_gen: if BYTE_ADDR = 1 generate
    waddr_o(MAX_CNT_WIDTH+OFFSET-1 downto OFFSET) <= waddr_s;
    waddr_o(waddr_o'left downto MAX_CNT_WIDTH+OFFSET) <= (others => '0');
    waddr_o(OFFSET-1 downto 0) <= (others => '0');
  end generate;
  word_addr_gen: if BYTE_ADDR = 0 generate
    waddr_o(MAX_CNT_WIDTH-1 downto 0) <= waddr_s;
    waddr_o(waddr_o'left downto MAX_CNT_WIDTH) <= (others => '0');
  end generate;

  strb_o <= strb_q;

end Behavioral;
