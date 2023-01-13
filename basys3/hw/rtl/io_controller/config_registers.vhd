-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity config_registers is
    Port ( clk_i : in STD_LOGIC;
           reset_n : in STD_LOGIC;
           addr_i : in STD_LOGIC_VECTOR (3 downto 0);
           addr_vld_i : in STD_LOGIC;
           uart_data_i : in STD_LOGIC_VECTOR (7 downto 0);
           uart_vld_i : in STD_LOGIC;
           addr_o : out STD_LOGIC_VECTOR (3 downto 0);
           data_o : out STD_LOGIC_VECTOR (7 downto 0);
           rd_en_o: out std_logic;
           data_rdy_o : out STD_LOGIC);
end config_registers;

architecture Behavioral of config_registers is

    type registers_t is array(integer range <>) of std_logic_vector(uart_data_i'range);
    
    signal registers_r                  : registers_t(0 to 2**addr_i'length -1);
    signal registers_s                  : registers_t(0 to 2**addr_i'length -1);
    
    signal data_out_s, data_out_r       : std_logic_vector(uart_data_i'range);
    signal addr_s, addr_r               : std_logic_vector(addr_i'range);
    signal addr_os, addr_or             : std_logic_vector(addr_i'range);
    signal data_rdy_s, data_rdy_r       : std_logic;
    
    signal rd_en_s, rd_en_r             : std_logic;
    
begin

rd_en_s     <= '1' when addr_vld_i = '1' else
               '0' when rd_en_r = '1' and uart_vld_i = '1' else
               rd_en_r;
               
addr_s      <= addr_i when addr_vld_i = '1' else
               addr_r;
               
addr_os         <= addr_r when rd_en_r = '1' and uart_vld_i = '1' else
                   addr_or;
               
process(rd_en_r, uart_vld_i, registers_r, uart_data_i)
begin
    for i in registers_r'range loop
        registers_s(i) <= registers_r(i);
    end loop;
    data_rdy_s      <= '0';
    if(rd_en_r = '1') then
       if(uart_vld_i = '1') then
            registers_s(to_integer(unsigned(addr_r))) <= uart_data_i;
            data_rdy_s      <= '1';
       end if;     
    end if;
end process;

process(clk_i)
begin
    if(rising_edge(clk_i)) then
        if(reset_n = '0') then
            registers_r     <= (others => (others => '0'));
            data_out_r      <= (others => '0');
            addr_r          <= (others => '0');
            addr_or         <= (others => '0');
            rd_en_r         <= '0';
            data_rdy_r      <= '0';
        else
            for i in registers_r'range loop
                registers_r(i) <= registers_s(i);
            end loop;
            data_out_r      <= data_out_s;
            addr_r          <= addr_s;
            addr_or         <= addr_os;
            rd_en_r         <= rd_en_s;
            data_rdy_r      <= data_rdy_s;
        end if;
    end if;
end process;



data_out_s      <= registers_s(to_integer(unsigned(addr_r)));


rd_en_o         <= rd_en_r;
addr_o          <= addr_or;
data_o          <= data_out_r;
data_rdy_o      <= data_rdy_r;

end Behavioral;
