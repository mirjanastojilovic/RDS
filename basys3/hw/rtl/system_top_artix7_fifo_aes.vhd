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
	
	ENTITY system_top IS
	  Port (
	    clk_in           : in std_logic;
	    reset_n_in       : in std_logic;
	    rx_i             : in std_logic;
	    tx_o             : out std_logic
	     );
	END system_top;
	
	ARCHITECTURE behavior OF system_top IS
	
	  -- Constants
	  constant N_SENT_SAMPLES   : integer := 256;
	  constant COARSE_WIDTH     : integer := 32;
	  constant FINE_WIDTH       : integer := 24;
	  constant SENSOR_WIDTH     : integer := 128; 
	  constant SENSOR_ENC_WIDTH : integer := 8;
	  constant ENCODER_WIDTH    : integer := 16; --32
	
	  -- Clock signals
	  signal clk_main, clk_aes, clk_sensor, clk_ttest : std_logic;
	
	  -- Clock enable signals
	  signal clk_main_en : std_logic;
	
	  -- Reset signals
	  signal reset_host_n    : std_logic;
	  signal aes_reset_final : std_logic;
	  signal reset_main_ps, reset_main_ns, reset_host_aes_ns, reset_host_sensor_ns, reset_host_ttest_ns : std_logic;
	  signal reset_host_aes_ps, reset_host_sensor_ps, reset_host_ttest_ps : std_logic;
	  signal locked : std_logic;
	
	  -- AES related signals
	  signal aes_data_is, aes_key_is, aes_data_os : std_logic_vector(127 downto 0);
	  signal aes_drdy_s, aes_dvld_s, aes_bsy_s, aes_krdy_s : std_logic;
	  signal aes_drdy_delayed_s, aes_dvld_delayed_s : std_logic;
	
	  -- Sensor signals
	  signal delay_line_s : std_logic_vector(SENSOR_WIDTH-1 downto 0); -- sensor delay line
	
	  -- Calibration signals
	  signal IDC : STD_LOGIC_VECTOR(COARSE_WIDTH-1 downto 0);
	  signal IDF : STD_LOGIC_VECTOR(4*FINE_WIDTH-1 downto 0);
	  signal enc_tag, ctrl_tag, done, trigger, trigger_sync: std_logic;
	
	  -- Control register signals
	  signal reg_addr_s     :  std_logic_vector(3 downto 0);
	  signal reg_data_s     :  std_logic_vector(7 downto 0);
	  signal reg_data_rdy_s :  std_logic;
	
	  signal zero : std_logic := '0';
	  
	  -- temperature 
	  signal temperature_s : STD_LOGIC_VECTOR(11 downto 0);
	  
	  --calibration signal
	  signal calib_s : std_logic_vector(127 downto 0);
	  
	
	  
	
	  attribute keep : string;
	  attribute keep of delay_line_s           : signal is "yes";
	  attribute keep of IDC                    : signal is "yes";
	  attribute keep of IDF                    : signal is "yes";
	  attribute keep of done                   : signal is "yes";
	  attribute keep of reg_addr_s             : signal is "yes";
	  attribute keep of reg_data_s             : signal is "yes";
	  attribute keep of reg_data_rdy_s         : signal is "yes";
	
	  attribute S : string;
	  attribute S of delay_line_s              : signal is "yes";
	  attribute S of IDC                       : signal is "yes";
	  attribute S of IDF                       : signal is "yes";
	  attribute S of done                      : signal is "yes";
	  attribute S of reg_addr_s                : signal is "yes";
	  attribute S of reg_data_s                : signal is "yes";
	  attribute S of reg_data_rdy_s            : signal is "yes";
	
	  attribute dont_touch : string;
	  attribute dont_touch of aes              : label is "yes";
	  attribute dont_touch of delay_line_s     : signal is "yes";
	  attribute dont_touch of IDC              : signal is "yes";
	  attribute dont_touch of IDF              : signal is "yes";
	  attribute dont_touch of done             : signal is "yes";
	  attribute dont_touch of reg_addr_s       : signal is "yes";
	  attribute dont_touch of reg_data_s       : signal is "yes";
	  attribute dont_touch of reg_data_rdy_s   : signal is "yes";
	  
	  component clock_generator
	  port(
	    -- Clock out ports
	    aes_clk    : out std_logic;
	    sensor_clk : out std_logic;
	    ttest_clk  : out std_logic;
	    -- Status and control signals
	    resetn     : in  std_logic;
	    locked     : out std_logic;
	    -- Clock in ports
	    clk_in1    : in  std_logic
	  );
	  end component;
	
	BEGIN
	
	  -- CLOCK GENERATION SYSTEM
	
	  -- CLOCK BUFFER FOR THE EXTERNAL CLOCK
	  BUFG_inst: BUFG
	  Port map (
	    O => clk_main,
	    I => clk_in
	  );
	
	  -- MMCM FOR CLOCK GENERATION
	  clock_generator_inst : clock_generator
	  Port map ( 
	   -- Clock out ports  
	    aes_clk    => clk_aes,
	    sensor_clk => clk_sensor,
	    ttest_clk  => clk_ttest,
	   -- Status and control signals                
	    resetn     => '1',
	    locked     => locked,
	    -- Clock in ports
	    clk_in1    => clk_main
	  );
	 
	  -- RESET GENERATION SYSTEM
	  reset_system: entity work.reset_wrapper
	  Port map (
	    clk_main               => clk_main,
	    clk_aes                => clk_aes,
	    clk_sensor             => clk_sensor,
	    clk_ttest              => clk_ttest,
	  
	    external_reset_n_in    => reset_n_in,
	    aes_host_reset_p_in    => reg_data_s(1),
	    aes_host_reset_addr_in => reg_addr_s,
	    aes_host_reset_vld_in  => reg_data_rdy_s,
	    system_host_reset_n_in => reset_host_n,
	    locked_in              => locked,
	
	    main_reset_p           => reset_main_ps,
	    main_reset_n           => reset_main_ns,
	    aes_reset_p            => open, 
	    aes_reset_n            => aes_reset_final,
	    aes_domain_reset_p     => reset_host_aes_ps,
	    aes_domain_reset_n     => reset_host_aes_ns,
	    sensor_reset_p         => reset_host_sensor_ps,
	    sensor_reset_n         => reset_host_sensor_ns,
	    ttest_reset_p          => reset_host_ttest_ps,
	    ttest_reset_n          => reset_host_ttest_ns
	  );
	  
	  -- COMMUNICATION SYSTEM
	  io_controller: entity work.io_wrapper
	  Generic map(
	    NUM_SAMPLE        => N_SENT_SAMPLES,
	    SENSOR_DATA_LEN   => SENSOR_ENC_WIDTH,
	    SENSOR_WIDTH      => SENSOR_WIDTH
	  )
	  Port map (
	    clk_ctrl_i        => clk_main,
	    clk_aes_i         => clk_aes, 
	    clk_trce_i        => clk_sensor,
	    clk_uart_i        => clk_main,
	    
	    reset_n_i         => reset_main_ns,
	    reset_host_aes_i  => reset_host_aes_ns,
	    reset_host_snsr_i => reset_host_ttest_ns,
	    
	    aes_D_i           => aes_data_os,
	    aes_D_vld_i       => aes_dvld_delayed_s,
	    aes_busy_i        => aes_bsy_s,
	    
	    sensor_data_i     => delay_line_s,
	    start_rec_i       => aes_drdy_s,
	    temperature_i     => temperature_s,
	    
	    uart_rx_i         => rx_i,
	    uart_tx_o         => tx_o,
	    
	    aes_D_o           => aes_data_is,
	    aes_D_rdy_o       => aes_drdy_s,
	    aes_K_o           => aes_key_is,
	    aes_K_rdy_o       => aes_krdy_s,
	    
	    calib_o           => calib_s,
	    
	    conf_reg_o        => reg_data_s,
	    conf_reg_addr_o   => reg_addr_s,
	    conf_reg_rdy_o    => reg_data_rdy_s,
	    
	    reset_host_n_o    => reset_host_n
	  );
	   
	
	  drdy_delay : entity work.sig_delay
	  Port map (
	   sig_in  => aes_drdy_s,
	   sig_out => aes_drdy_delayed_s,
	   clk      => clk_aes,
	   clk_en_p => clk_main_en,
	   reset_p  => reset_host_aes_ps
	  );
	
	  dvld_delay : entity work.sig_delay
	  Port map (
	   sig_in  => aes_dvld_s,
	   sig_out => aes_dvld_delayed_s,
	   clk      => clk_aes,
	   clk_en_p => clk_main_en,
	   reset_p  => reset_host_aes_ps
	  );
	
	  aes: entity work.AES_Comp
	  Port map(
	    Kin    => aes_key_is,
	    Din    => aes_data_is,
	    Dout   => aes_data_os,
	    Krdy   => aes_krdy_s,
	    Drdy   => aes_drdy_delayed_s,
	    Kvld   => open,
	    Dvld   => aes_dvld_s,
	    EncDec => zero,
	    EN     => clk_main_en,
	    BSY    => aes_bsy_s,
	    CLK    => clk_aes,
	    RSTn   => aes_reset_final
	  );
	
	
	  sensor: entity work.sensor_top
	  Generic map (
	    sens_length => SENSOR_WIDTH,
	    enc_length => ENCODER_WIDTH,
	    initial_delay => COARSE_WIDTH,
	    fine_delay => FINE_WIDTH 
	  )
	  Port map (
	    rst_n              => reset_host_sensor_ns,
	    sys_clk            => clk_sensor,
	    clk_en_p           => '1',
	    tag_i              => ctrl_tag,
	    initial_delay_conf => calib_s(31 downto 0),
	    fine_delay_conf    => calib_s(127 downto 32),
	    tag_o              => enc_tag,
	    delay_line_o       => delay_line_s,
	    sensor_clk_i       => clk_sensor
	  );
	 
	  
	   temp_sensor: entity work.basys3_xadc
	  PORT MAP (
	    clk => clk_sensor,
	    temperature => temperature_s
	  );
	  
	
	  clk_main_en <= '1';
	
	END;
