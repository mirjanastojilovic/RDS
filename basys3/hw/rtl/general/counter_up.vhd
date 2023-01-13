-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_up is
    generic (
        SIZE    : Positive := 1
    );
    port (
        n_reset_i   : in  std_logic;
        clk_i       : in  std_logic;
        load_i      : in  std_logic; -- prioritized load command --
        up_i        : in  std_logic; -- increment command --
        val_i       : in  std_logic_vector(SIZE-1 downto 0);
        val_o       : out std_logic_vector(SIZE-1 downto 0)
    );
end entity counter_up ;

architecture behave of counter_up is
    signal cnt_curr_s : std_logic_vector(val_i'range);
    signal cnt_fut_s  : std_logic_vector(val_i'range);
    signal cnt_up_s   : std_logic_vector(val_i'range);
begin
    -- ADD: incremental value --
    cnt_up_s  <= std_logic_vector(unsigned(cnt_curr_s) + 1);

    -- Choose value to load in register --
    cnt_fut_s <= val_i      when load_i = '1' else -- MUX:    load
                 cnt_up_s   when   up_i = '1' else -- MUX:    count
                 cnt_curr_s;                       -- OTHERS: hold

    -- REG: store current state, with async reset and sync load --
    UPDATE: process (n_reset_i, clk_i)
    begin
        if Rising_Edge(clk_i) then
            if n_reset_i = '0' then
                cnt_curr_s <= (others => '0');
            else
                cnt_curr_s <= cnt_fut_s;
            end if;
        end if;
    end process;

    -- Set output --
    val_o <= cnt_curr_s;
end architecture behave ;