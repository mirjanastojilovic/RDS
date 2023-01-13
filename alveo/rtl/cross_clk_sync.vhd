-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity cross_clk_sync is
  Port (
    clk_in           : in  STD_LOGIC;
    reset_clkin_n    : in  STD_LOGIC;
    clk_out          : in  STD_LOGIC;
    reset_clkout_n   : in  STD_LOGIC;
    data_i           : in  STD_LOGIC;
    data_o           : out STD_LOGIC);
end cross_clk_sync;

architecture Behavioral of cross_clk_sync is

  signal sync_stage_1, sync_stage_2, edge_detect, edge, data_q : std_logic;
  signal streached : std_logic := '0';

begin

  input_store : process(clk_in) is
  begin
    if(clk_in'event and clk_in = '1') then
      if(reset_clkin_n = '0') then
        data_q <= '0';
      else
        data_q <= data_i;
      end if;
    end if;
  end process;

  streacher : process(data_q, sync_stage_2) is
  begin
    if(sync_stage_2 = '1') then
      streached <= '0';
    elsif(data_q'event and data_q = '1') then
      streached <= '1';
    end if;
  end process;

  synchronizer: process(clk_out) is
  begin
    if(clk_out'event and clk_out = '1') then
      if(reset_clkout_n = '0') then
        sync_stage_1 <= '0';
        sync_stage_2 <= '0';
      else
        sync_stage_1 <= streached;
        sync_stage_2 <= sync_stage_1;
      end if;
    end if;
  end process;

  edge_detect_reg : process(clk_out) is
  begin
    if(clk_out'event and clk_out = '1') then
      if(reset_clkout_n = '0') then
        edge_detect  <=  '0';
      else
        edge_detect  <= sync_stage_2;
      end if;
    end if;
  end process;

  edge <= sync_stage_2 and not edge_detect;

  output_reg: process(clk_out) is
  begin
    if(clk_out'event and clk_out = '1') then
      if(reset_clkout_n = '0') then
        data_o <= '0';
      else
        data_o <= edge;
      end if;
    end if;
  end process;

end Behavioral;
