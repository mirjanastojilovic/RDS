-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.design_package.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity counter_simple is
  Generic(
    MAX : integer := 2048);
  Port (
    clk              : in  STD_LOGIC;
    clk_en_p         : in  STD_LOGIC;
    reset_n          : in  STD_LOGIC;
    cnt_en           : in  STD_LOGIC;
    count_o          : out  STD_LOGIC_VECTOR (log2(MAX)-1 downto 0);
    overflow_o_p     : out  STD_LOGIC;
    cnt_next_en_o_p  : out  STD_LOGIC);
end counter_simple;

architecture Behavioral of counter_simple is

  signal count_s : unsigned(log2(MAX)-1 downto 0) := (others => '0');
  signal count_q : unsigned(log2(MAX)-1 downto 0) := (others => '0');
  
begin

  process(clk) is
  begin
    if(clk'event and clk = '1') then
      if(reset_n = '0') then
        count_q <= (others => '0');
        overflow_o_p <= '0';
        cnt_next_en_o_p <= '0';
      elsif(clk_en_p = '1') then
        if(cnt_en = '1') then
          count_q <= count_s;
          if(count_s = 0) then
            overflow_o_p <= '1';
          else
            overflow_o_p <= '0';
          end if;
          if(count_s = (MAX-1)) then
            cnt_next_en_o_p <= '1';
          else
            cnt_next_en_o_p <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
  
  count_s <= count_q + 1;
  count_o <= std_logic_vector(count_q);

end Behavioral;


