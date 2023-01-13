-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity address_dec is
  port (
    clk_i       : in std_logic;
    addr_rdy_i  : in std_logic;
    addr_i      : in std_logic_vector(7 downto 0);
    n_en_i      : in std_logic;
    rst_output  : in std_logic;
    key_o       : out std_logic;
    mask_o      : out std_logic;
    data_o      : out std_logic;
    enc_o       : out std_logic;
    trace_o     : out std_logic;
    calib_o     : out std_logic;
    reg_update_o: out std_Logic;
    addr_o      : out std_logic_vector(7 downto 0);
    restart_o   : out std_logic
        );
end address_dec;

  architecture behave of address_dec is

    signal key_s, mask_s, data_s, enc_s, trace_s, restart_s, reg_update_s, calib_s  : std_logic;
    signal addr_s, addr_r : std_logic_vector(7 downto 0);

  begin

      process(clk_i, addr_i, addr_rdy_i, n_en_i)
        begin
              if(rising_edge(clk_i)) then
                restart_s    <= '0';
                reg_update_s<= '0';
                if(rst_output = '1') then
                  key_s       <= '0';
                  mask_s      <= '0';
                  data_s      <= '0';
                  enc_s       <= '0';
                  trace_s     <= '0';
                  restart_s   <= '0';
                  calib_s     <= '0';
                
                elsif(addr_rdy_i = '1' and n_en_i = '0') then
                  key_s       <= '0';
                  mask_s      <= '0';
                  data_s      <= '0';
                  enc_s       <= '0';
                  trace_s     <= '0';
                  restart_s   <= '0';
                  calib_s     <= '0';
                  addr_s      <= addr_i;
                    case addr_i is
                        when X"01" => key_s         <= '1';
                        when X"02" => mask_s        <= '1';
                        when X"03" => data_s        <= '1';
                        when X"04" => enc_s         <= '1';
                        when X"05" => trace_s       <= '1';
                        when X"06" => calib_s       <= '1';
                        when X"FF" => restart_s     <= '1';
                        when others => 
                            case addr_i(7 downto 4) is
                                when X"E"   => reg_update_s <= '1';
                                when others => null;
                            end case;
                  end case;
                end if;
            end if;
      end process;

      mask_o    <= mask_s;
      key_o     <= key_s;
      data_o    <= data_s;
      enc_o     <= enc_s;
      addr_o    <= addr_s;
      trace_o       <= trace_s;
      reg_update_o  <= reg_update_s;
      restart_o     <= restart_s;
      calib_o       <= calib_s;
      
  end behave;
