-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.design_package.all;

library unisim;
use unisim.vcomponents.all;

entity sensor_top is
  generic(
    sens_length        : integer := 256;
    enc_length         : integer := 32;
    initial_delay      : integer := 16;
    fine_delay         : integer := 4
  );
  port(
    sys_clk            : in  std_logic;
    rst_n              : in  std_logic;
    clk_en_p           : in  std_logic;
    sensor_clk_i       : in  std_logic;
    tag_i              : in  std_logic;
    initial_delay_conf : in  std_logic_vector(initial_delay-1 downto 0);
    fine_delay_conf    : in  std_logic_vector(4*fine_delay-1 downto 0);
    tag_o              : out std_logic;
    delay_line_o       : out std_logic_vector(sens_length - 1 downto 0)
  );
end sensor_top;

architecture synth of sensor_top is

  component sensor 
  generic (
    -- SET_NUMBER: unique number per sensor. If there is only one sensor, SET_NUMBER is fixed to 1. 
	    COARSE_WIDTH       : integer := 32; 
	    FINE_WIDTH         : integer := 24;
	    SENSOR_WIDTH       : integer := 128; 
	    SET_NUMBER         : integer := 1 
  );
  port (
    clk_i              : in  std_logic;
    sampling_clk_i     : in  std_logic;
    ID_coarse_i        : in  std_logic_vector(COARSE_WIDTH - 1 downto 0);
    ID_fine_i          : in std_logic_vector(4 * FINE_WIDTH - 1 downto 0);
    sensor_o           : out std_logic_vector(SENSOR_WIDTH - 1 downto 0)
  );
  end component;

  component BUFG
    port (
      O : out std_logic;
      I : in std_logic 
      );
  end component;
  
  component sensor_mmcm
    generic(PHASE_SHIFT : real :=  10.0);
    port (
      CLK_IN1  : in  std_logic;
      CLK_OUT1 : out std_logic
      );
  end component;
  
 

  signal delaym_0 :  std_logic_vector(sens_length - 1 downto 0);
  signal sensor_encoded : std_logic_vector(log2(sens_length) downto 0);
  
  signal tag_s : std_logic;
  signal tmp_clk : std_logic;
  signal locked : std_logic;
  signal feedback : std_logic;

  attribute KEEP : string;
  attribute S : string;
  attribute KEEP of delaym_0: signal is "true";
  attribute S of delaym_0: signal is "true";
  
begin

  tdc0 : sensor 
  generic map (
    COARSE_WIDTH      => initial_delay, 
    FINE_WIDTH         => fine_delay,
    SENSOR_WIDTH   => sens_length,
    SET_NUMBER         => 1) 
  port map (
     clk_i          => sensor_clk_i, 
    sampling_clk_i        => sys_clk,
    ID_coarse_i => initial_delay_conf,
    ID_fine_i    => fine_delay_conf,
    sensor_o         => delaym_0
  );

  delay_line_o <= delaym_0;

end synth;


