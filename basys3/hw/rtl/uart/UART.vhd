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

entity UART is
    Port ( clk : in STD_LOGIC;
           clk_aes : in std_logic;
           tx_start_i : in STD_LOGIC;
           data_i : in STD_LOGIC_VECTOR (7 downto 0);
           data_o : out STD_LOGIC_VECTOR (7 downto 0);
           rx_vld_o : out STD_LOGIC;
           tx_bsy_o : out STD_LOGIC;
           rx : in STD_LOGIC;
           tx : out STD_LOGIC           
           );
end UART;

architecture Behavioral of UART is


component txuartlite 
    port (
        i_clk : in std_logic;
        i_wr  : in std_logic;
        i_data: in std_logic_vector(7 downto 0);
        o_uart_tx : out std_logic;
        o_busy : out std_logic);
 end component;
 
 component rxuartlite 
    port (
        i_clk : in std_logic;
        i_uart_rx  : in std_logic;
        o_wr : out std_logic;
        o_data: out std_logic_vector(7 downto 0)
);
 end component;
 
 signal uart_rxd_meta_n     : std_logic;
 signal uart_rxd_synced_n   : std_logic;
 signal rx_vld_s, rx_vld_r, ack_in_r            : std_logic;
 signal rx_en, tx_en        : std_logic;
 signal rx_word_o_reg,rx_word_o_s, rx_word_o_sr       : std_logic_vector(7 downto 0);
 
 signal uart_vld_s, uart_vld_r, uart_debounce : std_logic;
 signal rx_async, rx_meta, rx_synced : std_logic;
 

begin

synced_rx:process(clk, rx)
begin
    if(rising_edge(clk))then
        rx_async  <= rx;
        rx_meta   <= rx_async;
        rx_synced <= rx_meta;
    end if;
end process;


  transmitter: txuartlite
    port map(
            i_clk       => clk,
            i_wr        => tx_start_i,
            i_data      => data_i,
            o_busy      => tx_bsy_o,
            o_uart_tx   => tx
            );

    receiver: rxuartlite
    port map(
            i_clk       => clk,
            i_uart_rx   => rx_synced,
            o_wr        => rx_vld_s,
            o_data      => rx_word_o_s
            );

 rx_vld_o <= rx_vld_s;
 
 data_o   <= rx_word_o_s;

end Behavioral;
