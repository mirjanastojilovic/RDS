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

entity sensor is
  generic(
    COARSE_WIDTH   : integer := 16; -- length of elements preceding the sensor
    FINE_WIDTH     : integer := 8;  -- intermediate carry8 elements
    SENSOR_WIDTH   : integer := 64; -- 64 registers are used for the measurments
    SET_NUMBER     : integer := 1   -- Unique number per sensor instance to group  them in the same RLOC system
  );
  port(
    clk_i          : in  std_logic;
    sampling_clk_i : in  std_logic;
    ID_coarse_i    : in  std_logic_vector(COARSE_WIDTH-1 downto 0);
    ID_fine_i      : in  std_logic_vector(8*FINE_WIDTH-1 downto 0);
    sensor_o       : out std_logic_vector(SENSOR_WIDTH - 1 downto 0)
  );
end sensor;

architecture sim of sensor is

  type sensor_array_type is array (0 to 2047) of std_logic_vector(7 downto 0);
  signal sensor_array : sensor_array_type := (
    X"fd", X"27", X"9e", X"f3", X"fa", X"c1", X"25", X"32", X"0e", X"0b", X"bb", X"55", X"3a", X"bb", X"75", X"74", 
    X"39", X"b3", X"e1", X"6a", X"b8", X"79", X"3c", X"8d", X"06", X"40", X"40", X"79", X"f8", X"ff", X"e2", X"90", 
    X"c9", X"73", X"f8", X"c4", X"57", X"88", X"1e", X"39", X"49", X"4c", X"61", X"44", X"1a", X"53", X"95", X"23", 
    X"28", X"d6", X"07", X"49", X"bb", X"48", X"87", X"7b", X"c5", X"72", X"25", X"8e", X"e3", X"ca", X"cd", X"c1", 
    X"f1", X"76", X"1a", X"20", X"c2", X"a8", X"65", X"25", X"5a", X"68", X"46", X"12", X"78", X"96", X"91", X"e6", 
    X"09", X"ac", X"60", X"e1", X"64", X"1b", X"85", X"58", X"4c", X"f3", X"f5", X"5d", X"35", X"83", X"61", X"d1", 
    X"bc", X"a7", X"29", X"0e", X"10", X"5d", X"f3", X"f4", X"68", X"4f", X"b2", X"9c", X"de", X"c8", X"0c", X"9d", 
    X"f0", X"c7", X"fa", X"3d", X"dc", X"08", X"f7", X"fd", X"d2", X"36", X"61", X"ec", X"3a", X"a4", X"f9", X"07", 
    X"8a", X"a6", X"ab", X"dd", X"17", X"ea", X"de", X"e3", X"69", X"c4", X"9c", X"ff", X"3e", X"e2", X"02", X"9a", 
    X"d4", X"cc", X"ea", X"34", X"46", X"01", X"7f", X"12", X"f9", X"ce", X"b9", X"20", X"dc", X"c2", X"6b", X"8a", 
    X"2b", X"cc", X"a6", X"ec", X"b1", X"d5", X"37", X"df", X"05", X"9b", X"88", X"2c", X"c4", X"e1", X"fd", X"fc", 
    X"1a", X"5a", X"b3", X"82", X"3a", X"0b", X"4e", X"d0", X"03", X"da", X"1a", X"16", X"25", X"61", X"eb", X"c7", 
    X"e6", X"a9", X"25", X"1e", X"14", X"2d", X"0e", X"02", X"07", X"61", X"c0", X"96", X"b2", X"b2", X"5c", X"24", 
    X"0d", X"7e", X"0c", X"92", X"a0", X"75", X"ae", X"a2", X"65", X"a4", X"1b", X"dd", X"18", X"b7", X"7d", X"82", 
    X"b6", X"8c", X"81", X"01", X"75", X"43", X"df", X"a8", X"f3", X"e8", X"cb", X"af", X"4e", X"2d", X"25", X"42", 
    X"2c", X"10", X"92", X"10", X"5d", X"2d", X"78", X"5c", X"8a", X"a4", X"f7", X"27", X"93", X"96", X"2a", X"cf", 
    X"05", X"f0", X"a7", X"af", X"ea", X"13", X"f1", X"b5", X"ed", X"9f", X"a2", X"4c", X"c5", X"0d", X"89", X"da", 
    X"89", X"bb", X"57", X"b9", X"c8", X"8e", X"25", X"68", X"48", X"bb", X"1c", X"81", X"c7", X"30", X"c3", X"8c", 
    X"c8", X"3d", X"e9", X"03", X"ae", X"96", X"75", X"84", X"58", X"38", X"08", X"af", X"67", X"c8", X"df", X"5d", 
    X"f4", X"2e", X"a3", X"5c", X"f6", X"ad", X"84", X"db", X"3e", X"69", X"4b", X"65", X"1d", X"8d", X"b3", X"77", 
    X"32", X"31", X"70", X"f0", X"d3", X"8c", X"d3", X"07", X"c0", X"b5", X"23", X"48", X"15", X"a3", X"91", X"e9", 
    X"ad", X"26", X"6b", X"03", X"33", X"36", X"a9", X"d7", X"19", X"2e", X"0c", X"35", X"4c", X"ec", X"9e", X"ac", 
    X"ae", X"c4", X"c7", X"b3", X"7b", X"ee", X"e1", X"1c", X"67", X"d5", X"ad", X"a1", X"87", X"65", X"3f", X"d4", 
    X"3a", X"51", X"a6", X"04", X"9b", X"73", X"c1", X"e7", X"87", X"a5", X"05", X"b9", X"99", X"3a", X"20", X"b4", 
    X"f3", X"13", X"80", X"01", X"d1", X"7d", X"83", X"8d", X"5d", X"73", X"75", X"36", X"c2", X"65", X"3a", X"5e", 
    X"b3", X"01", X"be", X"cd", X"73", X"d5", X"c5", X"6c", X"e0", X"1e", X"bc", X"80", X"36", X"e8", X"a5", X"bf", 
    X"0b", X"f5", X"9b", X"3e", X"dd", X"79", X"cd", X"a1", X"86", X"71", X"4b", X"fa", X"fb", X"87", X"1b", X"b2", 
    X"23", X"aa", X"ee", X"df", X"d9", X"f6", X"58", X"8c", X"68", X"89", X"da", X"cd", X"4c", X"2d", X"3a", X"33", 
    X"01", X"22", X"15", X"a3", X"33", X"dc", X"d2", X"ab", X"c9", X"99", X"1f", X"ff", X"f0", X"76", X"4b", X"7f", 
    X"cf", X"79", X"77", X"c1", X"9d", X"7d", X"66", X"76", X"01", X"6c", X"7a", X"f6", X"23", X"2e", X"35", X"13", 
    X"f1", X"22", X"9f", X"95", X"e5", X"e3", X"ba", X"54", X"35", X"1a", X"44", X"7b", X"2f", X"6d", X"6f", X"ef", 
    X"4b", X"81", X"ed", X"0b", X"bf", X"fa", X"95", X"8b", X"ac", X"5a", X"9a", X"ab", X"e3", X"bd", X"06", X"75", 
    X"5b", X"b6", X"8d", X"d6", X"83", X"2a", X"11", X"4e", X"a2", X"91", X"a5", X"94", X"bb", X"2d", X"2b", X"9f", 
    X"32", X"d7", X"59", X"02", X"b0", X"09", X"b7", X"88", X"45", X"cd", X"ce", X"88", X"a4", X"5e", X"af", X"5b", 
    X"c0", X"ee", X"83", X"33", X"f9", X"e6", X"5b", X"4f", X"01", X"78", X"c9", X"52", X"db", X"ba", X"b6", X"cb", 
    X"2b", X"06", X"63", X"35", X"c2", X"3c", X"1e", X"17", X"c4", X"c3", X"b6", X"d1", X"44", X"04", X"53", X"c1", 
    X"69", X"f4", X"ad", X"a2", X"2f", X"d1", X"21", X"ba", X"29", X"44", X"b4", X"b7", X"6f", X"c1", X"4e", X"9e", 
    X"4a", X"95", X"f2", X"f7", X"45", X"47", X"2d", X"cc", X"40", X"32", X"11", X"f0", X"3f", X"a8", X"4f", X"f2", 
    X"9b", X"51", X"0f", X"1f", X"d4", X"72", X"e5", X"5e", X"13", X"43", X"39", X"4b", X"28", X"d8", X"3d", X"cd", 
    X"94", X"8b", X"ab", X"c6", X"3d", X"31", X"a4", X"b7", X"5c", X"f5", X"77", X"2e", X"73", X"4f", X"54", X"4f", 
    X"f4", X"ad", X"fe", X"8b", X"71", X"31", X"9d", X"c6", X"cd", X"d0", X"97", X"c2", X"0b", X"8a", X"c3", X"4d", 
    X"4d", X"52", X"e0", X"a7", X"66", X"79", X"b7", X"8d", X"cc", X"02", X"76", X"8b", X"5b", X"54", X"5c", X"f4", 
    X"c2", X"77", X"66", X"23", X"c0", X"2a", X"7e", X"b8", X"0f", X"aa", X"3d", X"75", X"27", X"ee", X"4f", X"59", 
    X"da", X"b8", X"3c", X"00", X"21", X"0a", X"1f", X"4f", X"31", X"bc", X"0f", X"7b", X"72", X"68", X"8a", X"33", 
    X"3b", X"41", X"92", X"40", X"36", X"c3", X"bc", X"09", X"68", X"9e", X"12", X"1d", X"39", X"06", X"1b", X"41", 
    X"89", X"54", X"a7", X"05", X"63", X"4d", X"ef", X"eb", X"8a", X"47", X"bd", X"57", X"b5", X"93", X"7a", X"36", 
    X"08", X"b1", X"cb", X"32", X"a3", X"48", X"6b", X"ca", X"b8", X"9a", X"1b", X"ef", X"82", X"7b", X"c9", X"fd", 
    X"90", X"bf", X"a9", X"9e", X"5b", X"7f", X"ca", X"d0", X"9d", X"c8", X"3d", X"33", X"71", X"8b", X"c5", X"09", 
    X"cf", X"ba", X"45", X"0a", X"f1", X"ca", X"6e", X"24", X"41", X"d1", X"1d", X"9c", X"f6", X"26", X"1d", X"77", 
    X"b9", X"fa", X"fb", X"2f", X"6b", X"d7", X"89", X"e8", X"ac", X"5b", X"4d", X"f9", X"ce", X"57", X"b4", X"96", 
    X"3a", X"93", X"ab", X"a9", X"06", X"6d", X"99", X"f8", X"8b", X"2e", X"45", X"32", X"70", X"9f", X"24", X"3a", 
    X"90", X"43", X"b0", X"8c", X"cd", X"5d", X"c9", X"06", X"bf", X"66", X"3b", X"4d", X"92", X"86", X"3a", X"9c", 
    X"5f", X"20", X"72", X"d7", X"c5", X"86", X"a2", X"a1", X"e7", X"19", X"1d", X"de", X"6a", X"f5", X"2b", X"be", 
    X"b8", X"16", X"98", X"fd", X"d2", X"10", X"0f", X"77", X"8d", X"50", X"ad", X"df", X"8b", X"10", X"19", X"42", 
    X"86", X"a6", X"f7", X"ed", X"18", X"0f", X"56", X"7f", X"93", X"f9", X"cd", X"b7", X"91", X"a8", X"93", X"bf", 
    X"08", X"cd", X"c1", X"78", X"30", X"5c", X"58", X"dd", X"44", X"d9", X"6e", X"26", X"a3", X"13", X"af", X"b7", 
    X"fd", X"29", X"fb", X"87", X"cc", X"09", X"92", X"7c", X"6b", X"18", X"ea", X"4e", X"b8", X"7d", X"db", X"20", 
    X"14", X"24", X"0f", X"19", X"56", X"18", X"39", X"8c", X"b4", X"8d", X"96", X"6a", X"cb", X"eb", X"2e", X"07", 
    X"79", X"31", X"f8", X"2d", X"82", X"71", X"79", X"33", X"f3", X"bc", X"2b", X"11", X"94", X"70", X"e7", X"32", 
    X"88", X"f1", X"b3", X"d3", X"cf", X"e6", X"d9", X"ee", X"b5", X"1f", X"66", X"9e", X"6d", X"8a", X"72", X"68", 
    X"50", X"d8", X"ee", X"d9", X"a4", X"a5", X"a5", X"a7", X"e0", X"78", X"ee", X"7b", X"3c", X"99", X"0a", X"06", 
    X"58", X"83", X"6e", X"8d", X"11", X"fd", X"6b", X"98", X"59", X"de", X"27", X"7e", X"74", X"4e", X"33", X"c5", 
    X"73", X"ca", X"cc", X"72", X"9c", X"c9", X"c2", X"1f", X"37", X"82", X"b7", X"ec", X"e9", X"30", X"d3", X"8e", 
    X"61", X"23", X"9a", X"e8", X"48", X"03", X"a0", X"cf", X"b2", X"9e", X"ff", X"0d", X"f8", X"58", X"14", X"3f", 
    X"cb", X"1f", X"46", X"9c", X"bf", X"58", X"2f", X"11", X"f2", X"6c", X"e3", X"cc", X"78", X"06", X"4f", X"fd", 
    X"d3", X"8c", X"a0", X"46", X"a7", X"67", X"5a", X"74", X"36", X"02", X"82", X"cb", X"53", X"12", X"f2", X"da", 
    X"86", X"82", X"6e", X"ab", X"ef", X"24", X"da", X"80", X"8a", X"ba", X"95", X"62", X"07", X"a8", X"2f", X"69", 
    X"01", X"9e", X"18", X"8f", X"39", X"36", X"19", X"46", X"dc", X"17", X"2a", X"9e", X"3c", X"81", X"5a", X"ce", 
    X"be", X"96", X"c3", X"b9", X"10", X"00", X"4d", X"e2", X"83", X"5d", X"53", X"59", X"e7", X"83", X"fc", X"42", 
    X"54", X"14", X"59", X"c5", X"f6", X"55", X"4c", X"8b", X"dd", X"e4", X"1e", X"22", X"a6", X"79", X"a2", X"c2", 
    X"8f", X"c0", X"60", X"9c", X"42", X"77", X"cd", X"7f", X"a0", X"af", X"30", X"d2", X"ee", X"93", X"3c", X"f6", 
    X"62", X"b6", X"09", X"ea", X"89", X"a5", X"31", X"28", X"a3", X"36", X"1e", X"6e", X"ad", X"2c", X"ab", X"f2", 
    X"f3", X"c0", X"08", X"9f", X"97", X"d1", X"e8", X"92", X"7b", X"1f", X"44", X"5a", X"69", X"a2", X"aa", X"12", 
    X"87", X"d3", X"83", X"d2", X"48", X"a8", X"28", X"42", X"1f", X"74", X"6e", X"47", X"85", X"34", X"39", X"6f", 
    X"87", X"d2", X"48", X"59", X"09", X"e3", X"d3", X"f0", X"13", X"ae", X"0e", X"ca", X"a9", X"ef", X"31", X"81", 
    X"8b", X"a6", X"18", X"9f", X"e3", X"81", X"88", X"40", X"52", X"50", X"03", X"72", X"1c", X"10", X"16", X"90", 
    X"ae", X"35", X"9a", X"85", X"7c", X"43", X"83", X"6b", X"25", X"96", X"cb", X"6d", X"22", X"bf", X"91", X"3a", 
    X"b4", X"41", X"9b", X"7b", X"34", X"d1", X"cd", X"fa", X"63", X"9b", X"ca", X"f1", X"a9", X"0a", X"37", X"90", 
    X"dc", X"29", X"8f", X"b1", X"06", X"8a", X"9e", X"96", X"53", X"a6", X"cd", X"5c", X"4a", X"42", X"d1", X"81", 
    X"43", X"26", X"4c", X"f8", X"f0", X"28", X"2b", X"03", X"a6", X"de", X"ba", X"b8", X"ce", X"ca", X"c0", X"b7", 
    X"97", X"fe", X"ca", X"a5", X"30", X"f2", X"fc", X"98", X"16", X"94", X"12", X"c9", X"db", X"da", X"92", X"84", 
    X"21", X"b3", X"e8", X"2c", X"a6", X"d4", X"70", X"fc", X"06", X"b6", X"d9", X"76", X"98", X"d2", X"98", X"7a", 
    X"51", X"3d", X"3f", X"2e", X"b6", X"d9", X"e1", X"85", X"1b", X"8f", X"98", X"25", X"4d", X"9d", X"df", X"7d", 
    X"82", X"ad", X"23", X"ff", X"f0", X"18", X"a9", X"07", X"69", X"43", X"83", X"69", X"bc", X"58", X"52", X"ad", 
    X"9d", X"fd", X"ef", X"da", X"cb", X"41", X"1e", X"dc", X"c6", X"ed", X"d9", X"5d", X"6c", X"fc", X"2e", X"86", 
    X"e0", X"98", X"31", X"15", X"e6", X"19", X"08", X"4f", X"09", X"20", X"34", X"dc", X"de", X"04", X"c9", X"d9", 
    X"c7", X"40", X"1c", X"fc", X"65", X"0c", X"5e", X"75", X"41", X"af", X"90", X"c3", X"3c", X"a0", X"ea", X"3c", 
    X"06", X"44", X"eb", X"a2", X"b6", X"4c", X"47", X"e1", X"24", X"9b", X"b7", X"06", X"74", X"0d", X"c1", X"5e", 
    X"e4", X"b2", X"1e", X"25", X"e6", X"02", X"8a", X"50", X"fe", X"92", X"08", X"7b", X"ae", X"f8", X"09", X"1d", 
    X"da", X"ed", X"38", X"6e", X"7d", X"78", X"12", X"30", X"54", X"37", X"bd", X"83", X"40", X"7e", X"96", X"07", 
    X"4a", X"2b", X"3c", X"c5", X"3f", X"3b", X"04", X"52", X"d7", X"7f", X"a2", X"1e", X"78", X"57", X"b2", X"f0", 
    X"14", X"31", X"94", X"ac", X"b2", X"f4", X"9e", X"f4", X"18", X"08", X"a7", X"a8", X"0f", X"16", X"38", X"71", 
    X"84", X"0c", X"ac", X"b4", X"28", X"c6", X"51", X"d6", X"ae", X"1c", X"81", X"49", X"fc", X"5a", X"a0", X"9a", 
    X"fa", X"22", X"e8", X"a1", X"64", X"02", X"60", X"fb", X"ed", X"b0", X"0c", X"f9", X"a8", X"20", X"ec", X"58", 
    X"62", X"35", X"dc", X"5a", X"68", X"6f", X"48", X"1e", X"e7", X"e4", X"20", X"c1", X"20", X"a4", X"90", X"0a", 
    X"da", X"4a", X"1b", X"8c", X"2e", X"1d", X"bf", X"bd", X"e7", X"96", X"56", X"e7", X"13", X"6f", X"79", X"ec", 
    X"2a", X"a6", X"4e", X"3b", X"7f", X"19", X"13", X"96", X"0c", X"44", X"a3", X"84", X"68", X"25", X"f5", X"b0", 
    X"7e", X"12", X"9e", X"fb", X"4f", X"04", X"1a", X"66", X"cd", X"72", X"36", X"c5", X"0f", X"f4", X"70", X"6e", 
    X"d6", X"27", X"69", X"0e", X"81", X"7b", X"fa", X"ba", X"cf", X"44", X"8b", X"5c", X"d7", X"b6", X"cd", X"1f", 
    X"c3", X"0a", X"a1", X"6b", X"f9", X"98", X"b9", X"0e", X"fe", X"09", X"9b", X"33", X"e0", X"e7", X"69", X"83", 
    X"d2", X"80", X"f9", X"7d", X"32", X"92", X"08", X"93", X"4f", X"91", X"0f", X"3c", X"de", X"01", X"ca", X"55", 
    X"c6", X"08", X"bf", X"30", X"7b", X"e7", X"f3", X"a3", X"b0", X"d7", X"75", X"6e", X"4b", X"58", X"03", X"68", 
    X"90", X"82", X"3d", X"1d", X"a6", X"0d", X"f5", X"81", X"a3", X"80", X"7c", X"dc", X"ad", X"2b", X"cf", X"78", 
    X"46", X"fe", X"18", X"dd", X"e7", X"2a", X"c7", X"10", X"4a", X"84", X"7c", X"bf", X"c0", X"85", X"1e", X"54", 
    X"0b", X"ed", X"5e", X"f2", X"01", X"d5", X"2f", X"cd", X"04", X"6c", X"ad", X"bc", X"0c", X"86", X"66", X"e1", 
    X"ee", X"e2", X"46", X"d1", X"50", X"41", X"74", X"e5", X"18", X"c0", X"46", X"25", X"d4", X"43", X"b4", X"41", 
    X"00", X"b9", X"68", X"0a", X"47", X"a2", X"76", X"9e", X"e5", X"4a", X"f8", X"1a", X"bd", X"67", X"22", X"d0", 
    X"67", X"d3", X"ec", X"01", X"eb", X"37", X"e5", X"8a", X"48", X"63", X"7c", X"da", X"45", X"21", X"c3", X"22", 
    X"de", X"6d", X"ef", X"9d", X"db", X"34", X"d3", X"21", X"bf", X"90", X"28", X"0a", X"9f", X"d4", X"53", X"45", 
    X"af", X"b9", X"4f", X"4d", X"96", X"d0", X"47", X"71", X"2a", X"38", X"4d", X"74", X"5f", X"dd", X"5c", X"de", 
    X"87", X"52", X"3a", X"7c", X"90", X"38", X"b9", X"2f", X"e6", X"08", X"bd", X"bd", X"aa", X"e6", X"79", X"f2", 
    X"ce", X"4d", X"af", X"90", X"94", X"5a", X"f2", X"cb", X"13", X"9d", X"66", X"22", X"ac", X"17", X"ea", X"07", 
    X"b4", X"45", X"b1", X"e1", X"a8", X"99", X"30", X"9b", X"21", X"14", X"0c", X"dc", X"58", X"d6", X"a7", X"b1", 
    X"1a", X"c1", X"9a", X"48", X"c2", X"0c", X"84", X"c1", X"1d", X"aa", X"c3", X"d9", X"ef", X"83", X"18", X"d4", 
    X"14", X"c8", X"0a", X"24", X"97", X"f1", X"bd", X"ec", X"17", X"94", X"52", X"8a", X"26", X"29", X"df", X"59", 
    X"9b", X"44", X"77", X"bf", X"65", X"d3", X"37", X"83", X"45", X"04", X"11", X"33", X"21", X"37", X"eb", X"8a", 
    X"cd", X"10", X"c9", X"0c", X"2b", X"26", X"50", X"ae", X"cd", X"97", X"be", X"9c", X"b2", X"6f", X"7d", X"0c", 
    X"c2", X"c2", X"1e", X"47", X"92", X"c9", X"61", X"7c", X"61", X"fa", X"d8", X"20", X"a3", X"63", X"3c", X"cd", 
    X"3c", X"49", X"3a", X"3d", X"53", X"8f", X"1a", X"5c", X"f1", X"38", X"f9", X"99", X"fb", X"d3", X"d9", X"09", 
    X"a2", X"ba", X"5f", X"08", X"f2", X"27", X"a6", X"b5", X"f9", X"53", X"19", X"f6", X"b3", X"c5", X"cf", X"60", 
    X"d3", X"e9", X"c1", X"a9", X"2b", X"c0", X"77", X"7d", X"83", X"db", X"97", X"0e", X"5c", X"b2", X"3f", X"be", 
    X"04", X"14", X"c0", X"83", X"4f", X"d0", X"28", X"16", X"8b", X"d1", X"10", X"f2", X"99", X"ed", X"ca", X"8c", 
    X"a8", X"c0", X"87", X"05", X"44", X"f9", X"7e", X"44", X"14", X"3c", X"ce", X"45", X"0a", X"88", X"03", X"db", 
    X"e6", X"56", X"ed", X"de", X"a2", X"dd", X"5b", X"74", X"f2", X"03", X"20", X"d5", X"6c", X"ec", X"5f", X"d2", 
    X"fc", X"c6", X"e2", X"fe", X"40", X"46", X"25", X"7b", X"ed", X"30", X"d0", X"11", X"b3", X"88", X"d2", X"a9", 
    X"8f", X"80", X"01", X"d3", X"a1", X"d8", X"58", X"56", X"5a", X"42", X"6d", X"41", X"99", X"38", X"0c", X"60", 
    X"8b", X"93", X"32", X"5b", X"fd", X"00", X"15", X"ad", X"e1", X"c0", X"2b", X"ad", X"f0", X"ba", X"28", X"d7", 
    X"3a", X"1d", X"90", X"72", X"6e", X"14", X"cf", X"4b", X"75", X"51", X"65", X"96", X"ab", X"80", X"38", X"93");


  signal sample, sample_next : integer := 0;

begin 

  process(sampling_clk_i) is
  begin
    if(sampling_clk_i'event and sampling_clk_i='1') then
      if(sample_next > 2047) then
        sample <= 0;
      else
        sample <= sample_next;
      end if;
      sensor_o(7 downto 0) <= sensor_array(sample);
    end if;
  end process;

  sample_next <= sample + 1;

  sensor_o(sensor_o'left downto sensor_o'left-7) <= std_logic_vector(to_unsigned(SET_NUMBER, 8));
  

end sim;
