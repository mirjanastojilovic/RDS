-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.
	
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sensor_fifo is
  Generic(
    N_SAMPLES : integer := 128);
  Port(
    -- Write side, written to FIFO in burst when sens_trig is 1
    sens_fifo_din  : in  std_logic_vector(127 downto 0);
    sens_fifo_trig : in  std_logic;

    -- Read side, one sample read from FIFO at a time
    sens_fifo_drdy  : in  std_logic;
    sens_fifo_dout  : out std_logic_vector(127 downto 0);
    sens_fifo_dvld  : out std_logic;

    clk_wr          : in  std_logic;
    clk_rd          : in  std_logic;
    reset_wr_n      : in  std_logic;
    reset_rd_n      : in  std_logic
    );
end sensor_fifo;

architecture struct of sensor_fifo is

  COMPONENT fifo_generator_0
    PORT (
      rst         : IN  std_logic;
      wr_clk      : IN  std_logic;
      rd_clk      : IN  std_logic;
      din         : IN  std_logic_vector(127 DOWNTO 0);
      wr_en       : IN  std_logic;
      rd_en       : IN  std_logic;
      dout        : OUT std_logic_vector(127 DOWNTO 0);
      full        : OUT std_logic;
      wr_ack      : OUT std_logic;
      empty       : OUT std_logic;
      valid       : OUT std_logic;
      wr_rst_busy : OUT std_logic;
      rd_rst_busy : OUT std_logic
    );
  END COMPONENT;

  type WRITE_CU_states is (WAIT_ENC, WRITE_FIFO);
  signal state_reg, state_next : WRITE_CU_states;

  signal sens_fifo_din_q1 : std_logic_vector(127 downto 0);
  signal sens_fifo_din_q2 : std_logic_vector(127 downto 0);

  signal cnt_overflow_s : std_logic; 
  signal sens_fifo_wen  : std_logic; 
  signal cnt_en_s       : std_logic; 

  signal reset_p      : std_logic;
  
begin

  -- FIFO
  fifo: fifo_generator_0
  port map (
    rst         => reset_p, 
    wr_clk      => clk_wr, 
    rd_clk      => clk_rd, 
    din         => sens_fifo_din_q2, 
    wr_en       => sens_fifo_wen, 
    rd_en       => sens_fifo_drdy, 
    dout        => sens_fifo_dout, 
    full        => open, 
    wr_ack      => open, 
    empty       => open, 
    valid       => sens_fifo_dvld,
    wr_rst_busy => open,
    rd_rst_busy => open
  );

  reset_p <= not reset_rd_n;

  -- WRITE LOGIC, WORKING ON SENSOR CLOCK (clk_wr)

  -- State register
  write_state_proc: process(clk_wr) is
  begin
    if(clk_wr'event and clk_wr='1') then
      if(reset_wr_n = '0') then
        state_reg     <= WAIT_ENC;
        sens_fifo_din_q1 <= (others => '0');
        sens_fifo_din_q2 <= (others => '0');
      else
        state_reg     <= state_next;
        sens_fifo_din_q1 <= sens_fifo_din;
        sens_fifo_din_q2 <= sens_fifo_din_q1;
      end if;
    end if;
  end process;
  
  -- Next state logic
  write_next_state: process(state_reg, sens_fifo_trig, cnt_overflow_s) is
  begin
    case state_reg is
      when WAIT_ENC =>
        if(sens_fifo_trig = '0') then
          state_next <= WAIT_ENC;
        else
          state_next <= WRITE_FIFO;
        end if;
      when WRITE_FIFO =>
        if(cnt_overflow_s = '0') then
          state_next <= WRITE_FIFO;
        else
          state_next <= WAIT_ENC;
        end if;
    end case;
  end process;

  -- Moore output logic
  write_output_logic: process(state_reg) is
  begin
    -- default values
    sens_fifo_wen <= '0';
    cnt_en_s     <= '0';
    case state_reg is
      when WAIT_ENC =>
        sens_fifo_wen <= '0';
        cnt_en_s     <= '0';
      when WRITE_FIFO =>
        sens_fifo_wen <= '1';
        cnt_en_s     <= '1';
    end case;
  end process;

  -- Counter
  samples_cnt: entity work.counter_simple
  GENERIC MAP (
    MAX => N_SAMPLES
  )
  PORT MAP (
    clk              => clk_wr,
    clk_en_p         => '1',
    reset_n          => reset_wr_n,
    cnt_en           => cnt_en_s,
    count_o          => open,
    overflow_o_p     => open,
    cnt_next_en_o_p  => cnt_overflow_s
  );

end architecture;


