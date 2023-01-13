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
    --COARSE_WIDTH: number of LUT/LD elements preceding the sensor
    --FINE_WIDTH: number of CARRY4 elements preceding the sensor. Currently unused.
    --SENSOR_WIDTH: length of the sensor output
    --SET_NUMBER: unique number per sensor. If there is only one sensor, SET_NUMBER is fixed to 1. 
    COARSE_WIDTH       : integer := 32;
    FINE_WIDTH         : integer := 24;
    SENSOR_WIDTH       : integer := 128;
    SET_NUMBER         : integer := 1
  );
  port(
    --clk_i: clock that propagates through the elements
    --sampling_clk_i:  clock for the FDs
    --ID_coarse_i: specifies the number of LUTs/LD elements preceding the sensor
    --ID_fine_i: specifies the number of CARRY4 elements preceding the sensor. Currently unused.
    --sensor_o: output of the sensor
    clk_i                : in  std_logic;
    sampling_clk_i       : in  std_logic;
    ID_coarse_i          : in  std_logic_vector(COARSE_WIDTH-1 downto 0);
    ID_fine_i            : in std_logic_vector(4*FINE_WIDTH-1 downto 0);
    sensor_o             : out std_logic_vector(SENSOR_WIDTH - 1 downto 0)
  );
end sensor_top;

architecture synth of sensor_top is

  component sensor
  generic (
  --COARSE_WIDTH: number of LUT/LD elements preceding the sensor
  --FINE_WIDTH: number of CARRY4 elements preceding the sensor. Currently unnused
  --SENSOR_WIDTH: number of FDs used for the measurements
  --SET_NUMBER: unique number per sensor. If there is only one sensor, SET_NUMBER is fixed to 1. 
    COARSE_WIDTH       : integer := 32; 
    FINE_WIDTH         : integer := 24;
    SENSOR_WIDTH       : integer := 128; 
    SET_NUMBER         : integer := 1   
  );
  port (
   --clk_i: clock that propagates through the elements
   --sampling_clk_i:  clock for the FDs
   --ID_coarse_i: specifies the number of LUTs/LD elements preceding the sensor
   --ID_fine_i: specifies the number of CARRY4 elements preceding the sensor. Currently unnused
   --sensor_o: output of the sensor
    clk_i              : in  std_logic;
    sampling_clk_i     : in  std_logic;
    ID_coarse_i        : in  std_logic_vector(COARSE_WIDTH-1 downto 0);
    ID_fine_i          : in std_logic_vector(4*FINE_WIDTH-1 downto 0);
    sensor_o           : out std_logic_vector(SENSOR_WIDTH - 1 downto 0)
  );
  end component;
  
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of sensor_instance : label is "true";
  
begin

  sensor_instance : sensor 
  generic map (
    COARSE_WIDTH      => COARSE_WIDTH, 
    FINE_WIDTH        => FINE_WIDTH,
    SENSOR_WIDTH      => SENSOR_WIDTH,
    SET_NUMBER        => SET_NUMBER) 
  port map (
    clk_i             => clk_i, 
    sampling_clk_i    => sampling_clk_i,
    ID_coarse_i       => ID_coarse_i,
    ID_fine_i         => ID_fine_i,
    sensor_o          => sensor_o
  );

end synth;




