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

ENTITY sensor_top_multiple IS
    generic (
      --N_SENSORS: number of sensors
      --SENS_SET_BASE: id of the sensor
      --COARSE_WIDTH: number of LUT/LD elements preceding the sensor 
      --FINE_WIDTH: number of CARRY4 elements preceding the sensor. Currently unused
      --SENSOR_WIDTH: number of the sensor output
      N_SENSORS        : integer := 1;
      SENS_SET_BASE    : integer := 0;
      COARSE_WIDTH     : integer := 32;
      FINE_WIDTH       : integer := 24;
      SENSOR_WIDTH     : integer := 64
    );
  Port (
    --clk_i: clock that propagates through
    --dlay_line_o: output of the sensor
    --sens_calib_clk: clock for calibration signals
    --sens_calib_val: values for calibration (IDC/IDF)
    --sens_calib_trig: trigger signal for calibration values
    --sens_calib_id: id for each sensor
    clk_in           : in std_logic;
    dlay_line_o      : out std_logic_vector(N_SENSORS*SENSOR_WIDTH+32-1 downto 0);
    sens_calib_clk   : in std_logic;
    sens_calib_val   : in std_logic_vector(COARSE_WIDTH+FINE_WIDTH-1  downto 0);
    sens_calib_trg   : in std_logic;
    sens_calib_id    : in std_logic_vector(N_SENSORS-1 downto 0)
    );
END sensor_top_multiple;

ARCHITECTURE behavior OF sensor_top_multiple IS

  -- Sensor signals
  type delay_line_array is array (1 to N_SENSORS) of std_logic_vector(SENSOR_WIDTH-1 downto 0);
  signal delay_line_s : delay_line_array;
  signal state_alert: std_logic_vector(3 downto 0);

  -- Calibration signals
  type IDC_array is array (1 to N_SENSORS) of std_logic_vector(COARSE_WIDTH-1 downto 0);
  signal IDC : IDC_array := (others => (others => '0'));
  type IDF_array is array (1 to N_SENSORS) of std_logic_vector(FINE_WIDTH-1 downto 0);
  signal IDF : IDF_array := (others => (others => '0'));

  attribute keep : string;
  attribute keep of delay_line_s           : signal is "yes";
  attribute keep of IDC                    : signal is "yes";
  attribute keep of IDF                    : signal is "yes";

  attribute S : string;
  attribute S of delay_line_s              : signal is "yes";
  attribute S of IDC                       : signal is "yes";
  attribute S of IDF                       : signal is "yes";

  attribute dont_touch : string;
  attribute dont_touch of delay_line_s     : signal is "yes";
  attribute dont_touch of IDC              : signal is "yes";
  attribute dont_touch of IDF              : signal is "yes";

BEGIN

  sensor_gen: for i in 1 to N_SENSORS generate
    sensor: entity work.sensor_top
    Generic map (
      SENSOR_WIDTH => SENSOR_WIDTH,
      COARSE_WIDTH => COARSE_WIDTH,
      FINE_WIDTH => FINE_WIDTH/8,
      SET_NUMBER => SENS_SET_BASE+i
    )
    Port map (
      clk_i            => clk_in,
      ID_coarse_i      => IDC(i),
      ID_fine_i        => IDF(i),
      sensor_o         => delay_line_s(i),
      sampling_clk_i   => clk_in 
    );

    dlay_line_o(i*SENSOR_WIDTH-1 downto (i-1)*SENSOR_WIDTH) <= delay_line_s(i);

    IDC_IDF_reg: process(sens_calib_clk) is
    begin
      if(rising_edge(sens_calib_clk)) then
        if(sens_calib_trg = '1' and sens_calib_id(i-1) = '1') then
          IDC(i) <= sens_calib_val(COARSE_WIDTH-1 downto 0);
          IDF(i) <= sens_calib_val(COARSE_WIDTH+FINE_WIDTH-1 downto COARSE_WIDTH);
        end if;
      end if;
    end process;

  end generate;

END;

