-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.design_package.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

ENTITY sensor_wrapper_top IS
    generic (
    --COARSE_WIDTH: number of LUT/LD elements preceding the sensor 
    --FINE_WIDTH: number of CARRY4 elements preceding the sensor. Currently unused
    --SENSOR_WIDTH: length of the sensor output
        COARSE_WIDTH     : integer := 32;
        FINE_WIDTH       : integer := 24;
        SENSOR_WIDTH     : integer := 128
    );
  Port (
  --clk_in: clock that propagates throguh
  --IDC_IDF_en_i: enable signal for ID_coarse_i and ID_fine_i
  --ID_coarse_i: specifies the number of LUTs/LD elements preceding the sensor
  --ID_fine_i: specifies the number of CARRY4 elements preceding the sensor. Currently unused
    clk_i            : in  std_logic;
    IDC_IDF_en_i     : in std_logic;
    sensor_o         : out std_logic_vector(SENSOR_WIDTH-1 downto 0);
    ID_coarse_i      : in  std_logic_vector(COARSE_WIDTH-1 downto 0);
    ID_fine_i        : in  std_logic_vector(4*FINE_WIDTH-1 downto 0)
    );
END sensor_wrapper_top;

ARCHITECTURE behavior OF sensor_wrapper_top IS

  signal ID_coarse_s : std_logic_vector(COARSE_WIDTH-1 downto 0);
  signal ID_fine_s : std_logic_vector(4*FINE_WIDTH-1 downto 0);


  attribute keep : string;
  attribute keep of ID_coarse_s                  : signal is "yes";
  attribute keep of ID_fine_s                    : signal is "yes";

  attribute S : string;
  attribute S of ID_coarse_s                     : signal is "yes";
  attribute S of ID_fine_s                       : signal is "yes";

  attribute dont_touch : string;
  attribute dont_touch of ID_coarse_s            : signal is "yes";
  attribute dont_touch of ID_fine_s              : signal is "yes";

  
BEGIN
    proc: process(clk_i) is
  begin
    if(clk_i'event and clk_i='1') then
       if(IDC_IDF_en_i = '1') then
          ID_coarse_s <= ID_coarse_i;
          ID_fine_s <= ID_fine_i;
       end if;
    end if;  
  end process;
   

  
  sensor: entity work.sensor_top
  Generic map (
    SENSOR_WIDTH    => SENSOR_WIDTH,
    COARSE_WIDTH    => COARSE_WIDTH,
    FINE_WIDTH      => FINE_WIDTH,
    SET_NUMBER      => 1
  )
  Port map (
    clk_i           => clk_i,
    ID_coarse_i     => ID_coarse_s,
    ID_fine_i       => ID_fine_s,
    sensor_o        => sensor_o,
    sampling_clk_i  => clk_i 
  );
  

END;


