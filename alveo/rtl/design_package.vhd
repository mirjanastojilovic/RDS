-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

--package declaration
library ieee;
use ieee.std_logic_1164.all;
 
package design_package is
--constants
  
--functions
  function MAXIMUM(a, b : integer) return integer;
  function MAX3(a, b, c : integer) return integer;
  function log2(n : integer) return integer;
  function calculate_sensor_padding(MEAN_INT_BITS, SENSOR_INT_BITS : integer) return integer;
  function and_reduct(slv : in std_logic_vector) return std_logic;
  function or_reduct(slv : in std_logic_vector) return std_logic;
end design_package;

--package body
package body design_package is
  
  function MAXIMUM(a,b : integer) return integer is
  begin
    if (a >= b) then
      return a;
    else
      return b;
    end if;
  end MAXIMUM;

  function MAX3(a,b,c : integer) return integer is
  begin
    if (a >= b) then
      if(a >= c) then
        return a;
      else
        return c;
      end if;
    else
      if (b >= c) then
        return b;
      else
        return c;
      end if;
    end if;
  end MAX3;

  function log2(n : integer) return integer is
    variable m, p : integer;
  begin
    m := 0;
    p := 1;
    while (p < n) loop
      m := m+1;
      p := p*2;
    end loop;
    return m;
  end log2;
  
  function calculate_sensor_padding(MEAN_INT_BITS, SENSOR_INT_BITS : integer) return integer is
  begin
    if(MEAN_INT_BITS > SENSOR_INT_BITS) then
      return MEAN_INT_BITS-SENSOR_INT_BITS;
    elsif(MEAN_INT_BITS < SENSOR_INT_BITS) then
      return 0;
    else
      return 0;
    end if;
  end calculate_sensor_padding;
  
  function and_reduct(slv : in std_logic_vector) return std_logic is
    variable res_v : std_logic := '1';  -- Null slv vector will also return '1'
  begin
    for i in slv'range loop
      res_v := res_v and slv(i);
    end loop;
    return res_v;
  end function;

  function or_reduct(slv : in std_logic_vector) return std_logic is
    variable res_v : std_logic := '0';  -- Null slv vector will also return '0'
  begin
    for i in slv'range loop
      res_v := res_v or slv(i);
    end loop;
    return res_v;
  end function;

end design_package;
