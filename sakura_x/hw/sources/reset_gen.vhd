-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_gen is
  Generic(
    N_RESETS : integer := 1);
  PORT(
    reset_ext_in_n : in  std_logic;
    reset_aux_in_n : in  std_logic;
    locked         : in  std_logic;
    clocks         : in  std_logic_vector(N_RESETS-1 downto 0);
    resets_out_n   : out std_logic_vector(N_RESETS-1 downto 0);
    resets_out_p   : out std_logic_vector(N_RESETS-1 downto 0));
end reset_gen;

architecture struct of reset_gen is

  COMPONENT reset_generator
    PORT (
      slowest_sync_clk     : in  std_logic;
      ext_reset_in         : in  std_logic;
      aux_reset_in         : in  std_logic;
      mb_debug_sys_rst     : in  std_logic;
      dcm_locked           : in  std_logic;
      mb_reset             : out std_logic;
      bus_struct_reset     : out std_logic;
      peripheral_reset     : out std_logic;
      interconnect_aresetn : out std_logic;
      peripheral_aresetn   : out std_logic
    );
  END COMPONENT;

begin

  reset_generate: for i in 1 to N_RESETS generate
    reset_comp: reset_generator
    port map (
      slowest_sync_clk     => clocks(i-1),
      ext_reset_in         => reset_ext_in_n,
      aux_reset_in         => reset_aux_in_n,
      mb_debug_sys_rst     => '0',
      dcm_locked           => locked,
      mb_reset             => open,
      bus_struct_reset     => open,
      peripheral_reset     => resets_out_p(i-1),
      interconnect_aresetn => open,
      peripheral_aresetn   => resets_out_n(i-1)
    );
  end generate;


  
end struct;
