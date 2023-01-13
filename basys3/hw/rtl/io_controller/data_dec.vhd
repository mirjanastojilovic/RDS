-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity data_dec is
  generic (
    AES_DATA_LEN      : Positive := 128;
    UART_WORD_LEN     : Positive := 8
  );
  port (
    clk_i               : in std_logic;
    n_reset_i           : in std_logic;
    data_rdy_i          : in std_logic;
    start_dec_i         : in std_logic;
    word_i              : in std_logic_vector(UART_WORD_LEN-1 downto 0);

    data_vld_o          : out std_logic;
    data_o              : out std_logic_vector(AES_DATA_LEN-1 downto 0)
    );
end data_dec;

architecture behave of data_dec is

  signal data_vld_s, busy_s, data_vld_r     : std_logic;
  signal data_s, data_r         : std_logic_vector(AES_DATA_LEN-1 downto 0);
  signal curr_word_r, fut_word_s      : integer range 0 to AES_DATA_LEN/UART_WORD_LEN;
  signal dec_en_s, dec_en_r    : std_logic;
  signal cur_count, next_count        : integer;
  signal data_rdy_s    : std_logic;
begin

  input_process: process(start_dec_i, data_rdy_i, word_i, data_r, curr_word_r, dec_en_r, cur_count)
  begin
    data_s          <= data_r;
    data_vld_s      <= '0';
    fut_word_s      <= curr_word_r;
    dec_en_s        <= dec_en_r;
    next_count <= cur_count;
    if(start_dec_i = '1') then
      data_s        <= (others => '0');
      data_vld_s    <= '0';
      fut_word_s    <=  0;
      dec_en_s      <= '1';
    elsif(dec_en_r = '1') then
      if(curr_word_r = AES_DATA_LEN/UART_WORD_LEN) then
        data_vld_s  <= '1';
        dec_en_s    <= '0';
      elsif(data_rdy_i = '1') then
        next_count <= cur_count + 1;
        data_s(UART_WORD_LEN-1 + UART_WORD_LEN*curr_word_r downto UART_WORD_LEN*curr_word_r) <= word_i;
        fut_word_s <= curr_word_r + 1;
      end if;
    end if;
  end process;


  register_process: process(clk_i, n_reset_i)
  begin
    if(rising_edge(clk_i)) then
      if(n_reset_i = '0') then
        data_r          <= (others => '0');
        data_vld_r      <= '0';
        curr_word_r     <=  0;
        dec_en_r        <= '0';

      else
        data_vld_r      <= data_vld_s;
        data_r          <= data_s;
        curr_word_r     <= fut_word_s;
        dec_en_r        <= dec_en_s;

      end if;
    end if;
 end process;

  -- output assignment
 data_o     <= data_r;
 data_vld_o <= data_vld_r;

end behave;
