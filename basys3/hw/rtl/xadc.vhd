-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

Library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

library work;

entity basys3_xadc is
  port (
    clk         : in  std_logic;
    -- Temperature sensor, value in degrees celcius = ((ADC x 503.975) / 4096) - 273.15
    temperature : out std_logic_vector(11 downto 0)
  );
end basys3_xadc;

architecture behavior of basys3_xadc is

    signal ADC_out : std_logic_vector(15 downto 0); 

begin

    -- Instantiate the XADC primitive within the Series 7 Xilinx FPGA that the Basys 3 uses
    U0 : XADC
        generic map (
            INIT_40 => X"0000", -- config reg 0
            INIT_41 => X"410F", -- config reg 1
            INIT_42 => X"0400", -- config reg 2
            INIT_48 => X"0100", -- Sequencer channel selection
            INIT_49 => X"00C0", -- Sequencer channel selection
            INIT_4A => X"0000", -- Sequencer Average selection
            INIT_4B => X"0000", -- Sequencer Average selection
            INIT_4C => X"0000", -- Sequencer Bipolar selection
            INIT_4D => X"0000", -- Sequencer Bipolar selection
            INIT_4E => X"0000", -- Sequencer Acq time selection
            INIT_4F => X"0000", -- Sequencer Acq time selection
            INIT_50 => X"B5ED", -- Temp alarm trigger
            INIT_51 => X"57E4", -- Vccint upper alarm limit
            INIT_52 => X"A147", -- Vccaux upper alarm limit
            INIT_53 => X"CA33",  -- Temp alarm OT upper
            INIT_54 => X"A93A", -- Temp alarm reset
            INIT_55 => X"52C6", -- Vccint lower alarm limit
            INIT_56 => X"9555", -- Vccaux lower alarm limit
            INIT_57 => X"AE4E",  -- Temp alarm OT reset
            INIT_58 => X"5999",  -- Vccbram upper alarm limit
            INIT_5C => X"5111",  -- Vccbram lower alarm limit
            SIM_DEVICE => "7SERIES",
            SIM_MONITOR_FILE => "design.txt")
  port map (
    -- ALARMS: 8-bit (each) output: ALM, OT
    ALM          => open,             -- 8-bit output: Output alarm for temp, Vccint, Vccaux and Vccbram
    OT           => open,             -- 1-bit output: Over-Temperature alarm

    -- STATUS: 1-bit (each) output: XADC status ports
    BUSY         => open,             -- 1-bit output: ADC busy output
    CHANNEL      => open,          -- 5-bit output: Channel selection outputs
    EOC          => open,             -- 1-bit output: End of Conversion
    EOS          => open,             -- 1-bit output: End of Sequence
    JTAGBUSY     => open,             -- 1-bit output: JTAG DRP transaction in progress output
    JTAGLOCKED   => open,             -- 1-bit output: JTAG requested DRP port lock
    JTAGMODIFIED => open,             -- 1-bit output: JTAG Write to the DRP has occurred
    MUXADDR      => open,          -- 5-bit output: External MUX channel decode

    -- Auxiliary Analog-Input Pairs: 16-bit (each) input: VAUXP[15:0], VAUXN[15:0]
    VAUXN        => (others => '0'),            -- 16-bit input: N-side auxiliary analog input
    VAUXP        => (others => '0'),            -- 16-bit input: P-side auxiliary analog input

    -- CONTROL and CLOCK: 1-bit (each) input: Reset, conversion start and clock inputs
    CONVST       => '0',              -- 1-bit input: Convert start input
    CONVSTCLK    => '0',              -- 1-bit input: Convert start input
    RESET        => '0',              -- 1-bit input: Active-high reset

    -- Dedicated Analog Input Pair: 1-bit (each) input: VP/VN
    VN           => '0', -- 1-bit input: N-side analog input
    VP           => '0', -- 1-bit input: P-side analog input

    -- Dynamic Reconfiguration Port (DRP)
    DO           => ADC_out,
    DRDY         => open,
    DADDR        => b"000_0000", -- Address 0x00 / 0  : Temperature sensor, value in degrees celcius = ((ADC x 503.975) / 4096) - 273.15
    DCLK         => clk,
    DEN          => '1',
    DI           => (others => '0'),
    DWE          => '0'
  );
  
  temperature <= ADC_out(15 downto 4);

end behavior;
