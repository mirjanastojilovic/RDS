-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.design_package.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

ENTITY reset_wrapper IS
  Port (
    clk_main               : in  std_logic;
    clk_aes                : in  std_logic;
    clk_sensor             : in  std_logic;
    clk_ttest              : in  std_logic;
  
    external_reset_n_in    : in  std_logic; 
    aes_host_reset_p_in    : in  std_logic; 
    aes_host_reset_addr_in : in  std_logic_vector(3 downto 0);
    aes_host_reset_vld_in  : in  std_logic; 
    system_host_reset_n_in : in  std_logic; 
    locked_in              : in  std_logic; 

    main_reset_p           : out std_logic;  
    main_reset_n           : out std_logic; 
    aes_reset_p            : out std_logic; 
    aes_reset_n            : out std_logic; 
    aes_domain_reset_p     : out std_logic;  
    aes_domain_reset_n     : out std_logic; 
    sensor_reset_p         : out std_logic; 
    sensor_reset_n         : out std_logic; 
    ttest_reset_p          : out std_logic;
    ttest_reset_n          : out std_logic
  );
END reset_wrapper;

ARCHITECTURE struct OF reset_wrapper IS

  COMPONENT reset_gen
    PORT (
        slowest_sync_clk : IN STD_LOGIC;
        ext_reset_in : IN STD_LOGIC;
        aux_reset_in : IN STD_LOGIC;
        mb_debug_sys_rst : IN STD_LOGIC;
        dcm_locked : IN STD_LOGIC;
        mb_reset : OUT STD_LOGIC;
        bus_struct_reset : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        peripheral_reset : OUT STD_LOGIC;
        interconnect_aresetn : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        peripheral_aresetn : OUT STD_LOGIC
    );
  END COMPONENT;

  signal aes_reset_p_special, extend, aes_reset_n_host, reset_n_aes_n, reset_n_host_aes_ns, reset_n_host_aes_ps, aes_reset_n_s, main_reset_n_s : std_logic;
  signal shifter : std_logic_vector(15 downto 0);

begin

  process(clk_main) is
  begin
    if(clk_main'event and clk_main='1') then
      if(main_reset_n_s = '0') then
        aes_reset_p_special <= '0';
        shifter <= (others => '0');
        extend <= '0';
      elsif(aes_host_reset_vld_in = '1' and aes_host_reset_p_in = '1' and aes_host_reset_addr_in = "0000") then
        aes_reset_p_special <= '1';
        shifter <= X"0001";
        extend <= '1';
      elsif(shifter(shifter'high) = '1') then
        aes_reset_p_special <= '0';
        shifter <= (others => '0');
        extend <= '0';
      elsif(extend = '1') then
        shifter <= shifter(shifter'high-1 downto 0)&'0';
      end if;
    end if;
  end process;
  
  aes_reset_n_host <= not aes_reset_p_special;

  aes_reset : reset_gen
  PORT MAP (
    slowest_sync_clk     => clk_aes,
    ext_reset_in         => external_reset_n_in,
    aux_reset_in         => aes_reset_n_host,
    mb_debug_sys_rst     => '0',
    dcm_locked           => locked_in,
    mb_reset             => open,
    bus_struct_reset     => open,
    peripheral_reset     => open,
    interconnect_aresetn => open,
    peripheral_aresetn   => reset_n_aes_n
  );

  aes_domain_reset : reset_gen
  PORT MAP (
    slowest_sync_clk     => clk_aes,
    ext_reset_in         => external_reset_n_in,
    aux_reset_in         => system_host_reset_n_in,
    mb_debug_sys_rst     => '0',
    dcm_locked           => locked_in,
    mb_reset             => open,
    bus_struct_reset     => open,
    peripheral_reset     => reset_n_host_aes_ps,
    interconnect_aresetn => open,
    peripheral_aresetn   => reset_n_host_aes_ns
  );
  
  aes_reset_n_s <= '0' when reset_n_host_aes_ns = '0' or reset_n_aes_n = '0' else '1';
  aes_reset_n <= aes_reset_n_s;
  aes_reset_p <= not aes_reset_n_s;
  aes_domain_reset_p <= reset_n_host_aes_ps;
  aes_domain_reset_n <= reset_n_host_aes_ns;

  sensor_reset : reset_gen
  PORT MAP (
    slowest_sync_clk     => clk_sensor,
    ext_reset_in         => external_reset_n_in,
    aux_reset_in         => system_host_reset_n_in,
    mb_debug_sys_rst     => '0',
    dcm_locked           => locked_in,
    mb_reset             => open,
    bus_struct_reset     => open,
    peripheral_reset     => sensor_reset_p,
    interconnect_aresetn => open,
    peripheral_aresetn   => sensor_reset_n
  );

  ttest_reset : reset_gen
  PORT MAP (
    slowest_sync_clk     => clk_ttest,
    ext_reset_in         => external_reset_n_in,
    aux_reset_in         => system_host_reset_n_in,
    mb_debug_sys_rst     => '0',
    dcm_locked           => locked_in,
    mb_reset             => open,
    bus_struct_reset     => open,
    peripheral_reset     => ttest_reset_p,
    interconnect_aresetn => open,
    peripheral_aresetn   => ttest_reset_n
  );
  
  
  ctrl_rst : reset_gen
  PORT MAP (
    slowest_sync_clk     => clk_main,
    ext_reset_in         => external_reset_n_in,
    aux_reset_in         => '1',
    mb_debug_sys_rst     => '0',
    dcm_locked           => locked_in,
    mb_reset             => open,
    bus_struct_reset     => open,
    peripheral_reset     => main_reset_p,
    interconnect_aresetn => open,
    peripheral_aresetn   => main_reset_n_s
  );

  main_reset_n <= main_reset_n_s;

end architecture;
