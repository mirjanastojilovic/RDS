-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.
	
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;

library unisim;
use unisim.vcomponents.all;

-- This sensor consists of an initial delay line followed by registers that are horizontally aligned. 
-- The initial delay line has LUTs and open latches and each LUT gets the clock as input. Thanks to 
-- this design, it allows calibration at runtime. In addition, the observable delay line 
-- consists of registers only. The routing from the output of the last latch to all registers is fixed.

entity sensor is

  generic (
    -- COARSE_WIDTH: number of LUT/LD elements preceding the sensor
    -- FINE_WIDTH: number of CARRY4 elements preceding the sensor. Currently unused
    -- SENSOR_WIDTH: number of FDs used for the measurements
    -- SET_NUMBER: unique number per sensor. If there is only one sensor, SET_NUMBER is fixed to 1. 
    COARSE_WIDTH       : integer := 32; 
    FINE_WIDTH         : integer := 24;
    SENSOR_WIDTH       : integer := 128; 
    SET_NUMBER         : integer := 1 
  );
  port (
    --clk_i: clock that propagates through the elements
    --sampling_clk_i: clock for the FDs
    --ID_coarse_i: specifies the number of LUTs/LD elements preceding the sensor.
    --ID_fine_i: specifies the number of CARRY4 elements preceding the sensor. Currently unnused.
    --sensor_o: output of the sensor
    clk_i              : in  std_logic;
    sampling_clk_i     : in  std_logic;
    ID_coarse_i        : in  std_logic_vector(COARSE_WIDTH - 1 downto 0);
    ID_fine_i          : in std_logic_vector(4*FINE_WIDTH - 1 downto 0);
    sensor_o           : out std_logic_vector(SENSOR_WIDTH - 1 downto 0)
  );
end sensor;

architecture Behavioral of sensor is

  --LUTs that are used in the initial delay line
  component LUT5 
    generic (INIT: bit_vector(31 downto 0) := x"0000_0002");
    port (O  : out std_ulogic;
          I0 : in std_ulogic;
          I1 : in std_ulogic;
          I2 : in std_ulogic;
          I3 : in std_ulogic;
          I4 : in std_ulogic
          );
  end component;

  --LDs used (along with LUTs) in the initial delay line
  component LD 
    generic(INIT : bit := '0');
    port(Q : out std_ulogic := '0';
         D : in std_ulogic;
         G : in std_ulogic
         );
  end component;


  --FDs used in the observable delay line to take the measurements
  component FD 
    generic(INIT : bit := '0'); 
    port(Q : out std_ulogic;
         C : in std_ulogic;
         D : in std_ulogic
         );
  end component;


  signal ID_s : std_logic_vector(2 * COARSE_WIDTH - 1 downto 0);
  signal sensor_o_s : std_logic_vector(SENSOR_WIDTH - 1 downto 0) := (others => '0');

  --KEEP_HIERARCHY: prevent optimizations along the hierarchy boundaries
  attribute keep_hierarchy : string;
  attribute keep_hierarchy of Behavioral: architecture is "true";

  --BOX_TYPE: set instantiation type, avoid warnings
  attribute box_type : string;
  attribute box_type of LUT5 : component is "black_box";
  attribute box_type of LD : component is "black_box";
  attribute box_type of FD : component is "black_box";

  --U_SET: set user set constraints
  attribute U_SET : string;
  attribute U_SET of coarse_init : label is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of coarse_ld_init : label is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of pre_buf_chain_gen : label is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of sensor_o_regs : label is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of ID_s : signal is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of sensor_o_s : signal is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of LUT5 : component is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of LD : component is "chainset" & integer'image(SET_NUMBER);
  attribute U_SET of FD : component is "chainset" & integer'image(SET_NUMBER);

  --S (SAVE): save nets constraint and prevent optimizations
  attribute S : string; 
  attribute S of ID_s : signal is "true"; 
  attribute S of sensor_o_s : signal is "true";
  attribute S of pre_buf_chain_gen : label is "true";

  attribute S of sensor_o_regs : label is "true";
  attribute S of coarse_init : label is "true";
  attribute S of coarse_ld_init : label is "true";


  --KEEP: prevent optimizations 
  attribute keep : string; 
  attribute keep of sensor_o_s: signal is "true";
  attribute keep of clk_i: signal is "true";
  attribute keep of ID_s : signal is "true";

  --SYN_KEEP: keep externally visible
  attribute syn_keep : string; 
  attribute syn_keep of pre_buf_chain_gen : label is "true";

  attribute syn_keep of sensor_o_regs : label is "true";

  --DONT_TOUCH: prevent optimizations
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of ID_s : signal is "true";
  
  --EQUIVALENT_REGISTER_REMOVAL: disable removal of equivalent registers described at RTL level
  attribute equivalent_register_removal: string;
  attribute equivalent_register_removal of sensor_o_s : signal is "no";

  --CLOCK_SIGNAL: clock signal will go through combinatorial logic
  attribute clock_signal : string;
  attribute clock_signal of ID_s : signal is "no";

  --MAXDELAY: set max delay for chain and pre_chain
  attribute maxdelay : string;
  attribute maxdelay of ID_s : signal is "1000ms";

  --RLOC: Define relative location
  attribute RLOC : string;
  attribute RLOC of coarse_init: label is
    "X0" &
    "Y" & integer'image(0); 
  attribute RLOC of coarse_ld_init: label is
    "X0" &
    "Y" & integer'image(0); 
  

begin

  --First LUT/LD of initial delay line for calibration
  --The (INIT => X"0000_0002") defines the output for the cases when
  --clk_i=0 and when clk_i=1.
  coarse_init : LUT5 generic map(INIT => X"0000_0002")
    port map (O => ID_s(0), I0 => clk_i, I1 => '0', I2 => '0', I3 => '0', I4 => '0');
  coarse_ld_init : LD 
    port map (Q => ID_s(1), D => ID_s(0), G => '1');

  --LUTs/FDs of initial delay line for calibration
  pre_buf_chain_gen : for i in 1 to ID_s'high/2 generate
    attribute RLOC of lut_chain: label is
      "X" & integer'image(integer( i/4 )) &
      "Y0";
    attribute RLOC of ld_chain: label is
      "X" & integer'image(integer( i/4 )) &
      "Y0";
  begin

    --LUT_CHAIN: define the LUT. The (INIT => x"0000_00ac") defines the output
    --for the corresponding cases.
    lut_chain : LUT5 generic map (INIT => x"0000_00ac")
      port map (O => ID_s(2*i), I0 => ID_s(2*i-1), I1 => clk_i, I2 => ID_coarse_i(i), I3 => '0', I4 => '0');

    --LD_CHAIN: define the transparent LD
    ld_chain : LD 
      port map (Q => ID_s(2*i+1), D => ID_s(2*i), G => '1');
  end generate;

  

  --FDs of the observable delay line
  sensor_o_regs : for i in 0 to sensor_o_s'high generate
  begin
    obs_regs : FD
      port map(Q => sensor_o_s(i),
           C => sampling_clk_i,
           D => ID_s(ID_s'high)
           );

  end generate;

 sensor_o <= sensor_o_s;
end Behavioral;




