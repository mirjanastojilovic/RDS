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
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity FSM_FIFO is
    Port ( clk_i        : in STD_LOGIC;
           reset_n_i    : in STD_LOGIC;
           fifo_empty_i : in STD_LOGIC;
           reader_bsy_i : in STD_LOGIC;
           rinc_o       : out STD_LOGIC;
           data_vld_o   : out STD_LOGIC
         );
end FSM_FIFO;

architecture Behavioral of FSM_FIFO is

     type state_t is (
        WAIT_DATA, 
        READ_WORD, 
        CONSUME_WORD,
        WAIT_READER 
    );

    signal state_curr_r     : state_t;


begin

state_dec: process(clk_i)
begin
    if(rising_edge(clk_i)) then
        if(reset_n_i = '0') then
            state_curr_r <= WAIT_DATA;
            data_vld_o          <= '0';
            rinc_o              <= '0';
        else
            data_vld_o          <= '0';
            rinc_o              <= '0';
            case state_curr_r is
                when WAIT_DATA =>
                    if(fifo_empty_i = '0') then
                        state_curr_r <= READ_WORD;
                        data_vld_o  <= '1';
                     else
                        state_curr_r <= WAIT_DATA;
                     end if;
                when READ_WORD =>
                    state_curr_r     <= CONSUME_WORD;
                    rinc_o      <= '1';
                when CONSUME_WORD =>
                    state_curr_r     <= WAIT_READER;
                when WAIT_READER =>
                    if(reader_bsy_i = '0') then
                        state_curr_r <= WAIT_DATA;
                     else
                        state_curr_r <= WAIT_READER;
                     end if;
                when others =>
                    null;
            end case;
        end if;
    end if;
end process;

end Behavioral;
