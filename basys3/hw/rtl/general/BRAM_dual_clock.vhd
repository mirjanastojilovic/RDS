-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use std.textio.all;
use ieee.numeric_std.all;
use work.design_package.all;

entity bram_dual_clock is
  Generic(
    DATA_WIDTH  : integer := 144;                
    MEM_SIZE    : integer := 2048;
    ADDR_WIDTH  : integer := 16;          
    OUT_LATENCY : string  := "ONE_CYCLE";       
    C_INIT_FILE : string  := "NO_INIT_FILE"    
    );
  Port(
    clk_a : IN STD_LOGIC;
    clk_b : IN STD_LOGIC;

    ena    : IN STD_LOGIC;
    regcea : IN STD_LOGIC; 
    rsta   : IN STD_LOGIC;

    wea    : IN  STD_LOGIC;
    dina   : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1      DOWNTO 0);
    addra  : IN  STD_LOGIC_VECTOR(ADDR_WIDTH-1      DOWNTO 0);
    douta  : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1      DOWNTO 0);


    enb    : IN STD_LOGIC;
    regceb : IN STD_LOGIC; 
    rstb   : IN STD_LOGIC;

    web    : IN  STD_LOGIC;
    dinb   : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1      DOWNTO 0);
    addrb  : IN  STD_LOGIC_VECTOR(ADDR_WIDTH-1      DOWNTO 0);
    doutb  : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1      DOWNTO 0)
  );
end bram_dual_clock;

architecture structural of bram_dual_clock is

  type ram_type is array(0 to MEM_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

  -- INIT RAM WITH FILE
  impure function initramfromfile (ramfilename : in string) return ram_type is
  file ramfile	: text is in ramfilename;
    variable ramfileline : line;
    variable ram_name	: ram_type;
    variable bitvec : bit_vector(DATA_WIDTH-1 downto 0);
  begin
    for i in ram_type'range loop
        readline (ramfile, ramfileline);
        read (ramfileline, bitvec);
        ram_name(i) := to_stdlogicvector(bitvec);
    end loop;
    return ram_name;
  end function;

  -- CHECK IF RAM NEEDS TO BE INIT
  impure function init_from_file_or_zeroes(ramfile : string) return ram_type is
    variable ram_zeros : ram_type := (others => (others => '0'));
  begin
    if ramfile = "NO_INIT_FILE" then
        return ram_zeros;
    else
        return InitRamFromFile(ramfile);
    end if;
  end;

  signal ram_data_a : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram_data_b : std_logic_vector(DATA_WIDTH-1 downto 0);

  shared variable bram_memory : ram_type := init_from_file_or_zeroes(C_INIT_FILE);

  signal douta_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
  signal doutb_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

  attribute ram_style: string;
  attribute ram_style of bram_memory: variable is "block";

begin

  process(clk_a, clk_b)
  begin
    if(clk_a'event and clk_a = '1') then
      if(ena = '1') then
        if(wea = '1') then
          bram_memory(to_integer(unsigned(addra))) := dina;
          ram_data_a <= dina;
        else 
          ram_data_a <= bram_memory(to_integer(unsigned(addra)));
        end if;
      end if;
    end if;
    if(clk_b'event and clk_b = '1') then
      if(enb = '1') then
          if(web = '1') then
            bram_memory(to_integer(unsigned(addrb))) := dinb;
            ram_data_b <= dinb;
          else
            ram_data_b <= bram_memory(to_integer(unsigned(addrb)));
          end if;
     end if;
    end if;
  end process;

  --  Following code generates ONE_CYCLE (no output register)
  --  Following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing
  no_output_register : if OUT_LATENCY = "ONE_CYCLE" generate
    douta <= ram_data_a;
    doutb <= ram_data_b;
  end generate;

  --  Following code generates TWO_CYCLES (use output register)
  --  Following is a 2 clock cycle read latency with improved clock-to-out timing
  output_register : if OUT_LATENCY = "TWO_CYCLES"  generate

    process(clk_a, clk_b)
    begin
      if(clk_a'event and clk_a = '1') then
        if(rsta = '1') then
          douta_reg <= (others => '0');
        elsif(regcea = '1') then
          douta_reg <= ram_data_a;
        end if;
      end if;
      if(clk_b'event and clk_b = '1') then
        if(rstb = '1') then
          doutb_reg <= (others => '0');
        elsif(regceb = '1') then
          doutb_reg <= ram_data_b;
        end if;
      end if;
    end process;
    douta <= douta_reg;
    doutb <= doutb_reg;

  end generate;

end structural;
