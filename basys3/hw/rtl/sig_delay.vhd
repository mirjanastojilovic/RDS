-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sig_delay is
    Port ( 
      sig_in  : in  STD_LOGIC;
      sig_out : out  STD_LOGIC;
      clk      : in  STD_LOGIC;
      clk_en_p : in  STD_LOGIC;
      reset_p  : in  STD_LOGIC);
end sig_delay;

architecture Behavioral of sig_delay is

  signal sig_d : std_logic_vector(13 downto 0);

begin

  process(clk) is
  begin
    if(clk'event and clk = '1') then
      if(reset_p = '1') then
        sig_d <= (others => '0');
        sig_out <= '0';
      elsif(clk_en_p = '1') then
        sig_d(0) <= sig_in;
        sig_d(1) <= sig_d(0);
        sig_d(2) <= sig_d(1);
        sig_d(3) <= sig_d(2);
        sig_d(4) <= sig_d(3);
        sig_d(5) <= sig_d(4);
        sig_d(6) <= sig_d(5);
        sig_d(7) <= sig_d(6);
        sig_d(8) <= sig_d(7);
        sig_d(9) <= sig_d(8);
        sig_d(10) <= sig_d(9);
        sig_d(11) <= sig_d(10);
        sig_d(12) <= sig_d(11);
        sig_d(13) <= sig_d(12);
        sig_out  <= sig_d(13);
      end if;
    end if;
  end process;
  
end Behavioral;

