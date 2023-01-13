-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.
	
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.design_package.all;

entity AES_SCA_kernel is
  port (
  ap_clk                : in  std_logic;
  ap_rst_n              : in  std_logic;
  -- AXI Master
  -- Dumps the BRAM content to DRAM
  m_axi_bank_0_AWADDR   : out std_logic_vector( 63 downto 0);
  m_axi_bank_0_AWLEN    : out std_logic_vector(  7 downto 0);
  m_axi_bank_0_AWSIZE   : out std_logic_vector(  2 downto 0);
  m_axi_bank_0_AWVALID  : out std_logic;
  m_axi_bank_0_AWREADY  : in  std_logic;
  m_axi_bank_0_WDATA    : out std_logic_vector(511 downto 0);
  m_axi_bank_0_WSTRB    : out std_logic_vector( 63 downto 0);
  m_axi_bank_0_WVALID   : out std_logic;
  m_axi_bank_0_WLAST    : out std_logic;
  m_axi_bank_0_WREADY   : in  std_logic;
  m_axi_bank_0_BRESP    : in  std_logic_vector(  1 downto 0);
  m_axi_bank_0_BVALID   : in  std_logic;
  m_axi_bank_0_BREADY   : out std_logic;
  -- AXI Lite Slave
  -- Used by the host to configure the experiments 
  s_axi_control_AWADDR  : in  std_logic_vector( 11 downto 0);
  s_axi_control_AWVALID : in  std_logic;
  s_axi_control_AWREADY : out std_logic;
  s_axi_control_WDATA   : in  std_logic_vector( 31 downto 0);
  s_axi_control_WSTRB   : in  std_logic_vector(  3 downto 0);
  s_axi_control_WVALID  : in  std_logic;
  s_axi_control_WREADY  : out std_logic;
  s_axi_control_BRESP   : out std_logic_vector(  1 downto 0);
  s_axi_control_BVALID  : out std_logic;
  s_axi_control_BREADY  : in  std_logic;
  s_axi_control_ARADDR  : in  std_logic_vector( 11 downto 0);
  s_axi_control_ARVALID : in  std_logic;
  s_axi_control_ARREADY : out std_logic;
  s_axi_control_RDATA   : out std_logic_vector( 31 downto 0);
  s_axi_control_RRESP   : out std_logic_vector(  1 downto 0);
  s_axi_control_RVALID  : out std_logic;
  s_axi_control_RREADY  : in  std_logic
  );
end AES_SCA_kernel;

architecture struct of AES_SCA_kernel is

  constant N_SENSORS            : integer := 1;
  constant IDC_SIZE             : integer := 32;
  constant IDF_SIZE             : integer := 96;
  constant C_S00_AXI_DATA_WIDTH : integer := 32;
  constant C_S00_AXI_ADDR_WIDTH : integer := 12;
  constant N_SAMPLES            : integer := 2048;
  constant SENSOR_WIDTH         : integer := 128;
  constant TRACE_BRAM_SIZE      : integer := 4096;

  signal aes_clk, aes_rstn, aes_rstn_sync : std_logic;
  signal key, ciphertext, plaintext : std_logic_vector(127 downto 0);
  signal krdy, krdy_sync, kvld, aes_start, aes_start_sync, aes_bsy, aes_done : std_logic;

  signal sens_trg, sens_calib_trg, dump_idle, sens_rst_n : std_logic;
  signal sens_calib_val : std_logic_vector(IDC_SIZE+IDF_SIZE-1 downto 0);
  signal sens_calib_id : std_logic_vector(N_SENSORS-1 downto 0);
  signal base_ptr : std_logic_vector(63 downto 0);

  signal trace_bram_rdata : std_logic_vector(511 downto 0);
  signal trace_bram_raddr : std_logic_vector(log2(TRACE_BRAM_SIZE)-1 downto 0);
  signal start_dump, start_dump_sync, trace_bram_ren : std_logic;

  signal sens_clk : std_logic;
  signal sensor_val : std_logic_vector(N_SENSORS*SENSOR_WIDTH+32-1 downto 0);
  signal sensor_val_ext : std_logic_vector(511 downto 0);

  signal trace_bram_wdata, wdatab : std_logic_vector(511 downto 0);
  signal trace_bram_waddr : std_logic_vector(log2(TRACE_BRAM_SIZE)-1 downto 0);
  signal trace_bram_wstrb, wenb : std_logic_vector(63 downto 0);
  signal trace_bram_wen : std_logic;

  signal bram_dump_idle : std_logic;

  signal locked : std_logic;
  signal one_const : std_logic := '1';
  signal zero_const : std_logic := '0';

  component rst_gen
    port (
        slowest_sync_clk     : in  std_logic;
        ext_reset_in         : in  std_logic;
        aux_reset_in         : in  std_logic;
        mb_debug_sys_rst     : in  std_logic;
        dcm_locked           : in  std_logic;
        mb_reset             : out std_logic;
        bus_struct_reset     : out std_logic_vector(0 downto 0);
        peripheral_reset     : out std_logic;
        interconnect_aresetn : out std_logic_vector(0 downto 0);
        peripheral_aresetn   : out std_logic
    );
  end component;

  signal m_axi_bank_0_AWADDR_s   : std_logic_vector( 63 downto 0);
  signal m_axi_bank_0_AWLEN_s    : std_logic_vector(  7 downto 0);
  signal m_axi_bank_0_AWSIZE_s   : std_logic_vector(  2 downto 0);
  signal m_axi_bank_0_AWVALID_s  : std_logic;
  signal m_axi_bank_0_AWREADY_s  : std_logic;
  signal m_axi_bank_0_WDATA_s    : std_logic_vector(511 downto 0);
  signal m_axi_bank_0_WSTRB_s    : std_logic_vector( 63 downto 0);
  signal m_axi_bank_0_WVALID_s   : std_logic;
  signal m_axi_bank_0_WLAST_s    : std_logic;
  signal m_axi_bank_0_WREADY_s   : std_logic;
  signal m_axi_bank_0_BRESP_s    : std_logic_vector(  1 downto 0);
  signal m_axi_bank_0_BVALID_s   : std_logic;
  signal m_axi_bank_0_BREADY_s   : std_logic;
  signal s_axi_control_AWADDR_s  : std_logic_vector( 11 downto 0);
  signal s_axi_control_AWVALID_s : std_logic;
  signal s_axi_control_AWREADY_s : std_logic;
  signal s_axi_control_WDATA_s   : std_logic_vector( 31 downto 0);
  signal s_axi_control_WSTRB_s   : std_logic_vector(  3 downto 0);
  signal s_axi_control_WVALID_s  : std_logic;
  signal s_axi_control_WREADY_s  : std_logic;
  signal s_axi_control_BRESP_s   : std_logic_vector(  1 downto 0);
  signal s_axi_control_BVALID_s  : std_logic;
  signal s_axi_control_BREADY_s  : std_logic;
  signal s_axi_control_ARADDR_s  : std_logic_vector( 11 downto 0);
  signal s_axi_control_ARVALID_s : std_logic;
  signal s_axi_control_ARREADY_s : std_logic;
  signal s_axi_control_RDATA_s   : std_logic_vector( 31 downto 0);
  signal s_axi_control_RRESP_s   : std_logic_vector(  1 downto 0);
  signal s_axi_control_RVALID_s  : std_logic;
  signal s_axi_control_RREADY_s  : std_logic;

begin

  m_axi_bank_0_AWADDR     <= m_axi_bank_0_AWADDR_s;
  m_axi_bank_0_AWLEN      <= m_axi_bank_0_AWLEN_s;
  m_axi_bank_0_AWSIZE     <= m_axi_bank_0_AWSIZE_s;
  m_axi_bank_0_AWVALID    <= m_axi_bank_0_AWVALID_s;
  m_axi_bank_0_AWREADY_s  <= m_axi_bank_0_AWREADY;
  m_axi_bank_0_WDATA      <= m_axi_bank_0_WDATA_s;
  m_axi_bank_0_WSTRB      <= m_axi_bank_0_WSTRB_s;
  m_axi_bank_0_WVALID     <= m_axi_bank_0_WVALID_s;
  m_axi_bank_0_WLAST      <= m_axi_bank_0_WLAST_s;
  m_axi_bank_0_WREADY_s   <= m_axi_bank_0_WREADY;
  m_axi_bank_0_BRESP_s    <= m_axi_bank_0_BRESP;
  m_axi_bank_0_BVALID_s   <= m_axi_bank_0_BVALID;
  m_axi_bank_0_BREADY     <= m_axi_bank_0_BREADY_s;
  s_axi_control_AWADDR_s  <= s_axi_control_AWADDR;
  s_axi_control_AWVALID_s <= s_axi_control_AWVALID;
  s_axi_control_AWREADY   <= s_axi_control_AWREADY_s;
  s_axi_control_WDATA_s   <= s_axi_control_WDATA;
  s_axi_control_WSTRB_s   <= s_axi_control_WSTRB;
  s_axi_control_WVALID_s  <= s_axi_control_WVALID;
  s_axi_control_WREADY    <= s_axi_control_WREADY_s;
  s_axi_control_BRESP     <= s_axi_control_BRESP_s;
  s_axi_control_BVALID    <= s_axi_control_BVALID_s;
  s_axi_control_BREADY_s  <= s_axi_control_BREADY;
  s_axi_control_ARADDR_s  <= s_axi_control_ARADDR;
  s_axi_control_ARVALID_s <= s_axi_control_ARVALID;
  s_axi_control_ARREADY   <= s_axi_control_ARREADY_s;
  s_axi_control_RDATA     <= s_axi_control_RDATA_s;
  s_axi_control_RRESP     <= s_axi_control_RRESP_s;
  s_axi_control_RVALID    <= s_axi_control_RVALID_s;
  s_axi_control_RREADY_s  <= s_axi_control_RREADY;

  AxiLiteFSM: entity work.AxiLiteFSM
  generic map (
    N_SENSORS            => N_SENSORS,
    IDC_SIZE             => IDC_SIZE,
    IDF_SIZE             => IDF_SIZE,
    C_S00_AXI_DATA_WIDTH => C_S00_AXI_DATA_WIDTH,
    C_S00_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
  )
  port map (
    -----------------------------------------------------------------------------
    -- FSM output signals
    -----------------------------------------------------------------------------
    ---- AES control signals
    ------ AES reset signals
    aes_rstn       => aes_rstn,
    ------ AES key signals
    key            => key,
    krdy           => krdy,
    kvld           => kvld,
    ------ AES control signals
    plaintext      => plaintext,
    ciphertext     => ciphertext,
    aes_start      => aes_start,
    aes_bsy        => aes_bsy,
    aes_done       => aes_done,
    ---- Trace recording trigger
    sens_trg       => sens_trg,
    dump_idle      => dump_idle,
    ---- Sensor calibration control signals
    ------ Calibration value
    sens_calib_val => sens_calib_val,
    ------ Sensor to be calibrated 
    sens_calib_id  => sens_calib_id,
    ------ Calibration trigger 
    sens_calib_trg => sens_calib_trg,
    ---- Sensor traces offloading from BRAM to DRAM
    ------ Base pointer in DRAM
    base_ptr       => base_ptr,
    -- DEBUG
    bram_dump_idle => bram_dump_idle,
    start_dump     => start_dump,
    start_dump_sync=> start_dump_sync,
    -----------------------------------------------------------------------------
    -- Ports of Axi Lite Slave Interface S00_AXI
    -----------------------------------------------------------------------------
    ---- clk and reset
    aclk           => ap_clk,
    aresetn        => ap_rst_n,
    ---- AXI Lite write signals
    ------ write address signals
    awaddr         => s_axi_control_AWADDR_s,
    awvalid        => s_axi_control_AWVALID_s,
    awready        => s_axi_control_AWREADY_s,
    ------ write data signals
    wdata          => s_axi_control_WDATA_s,
    wstrb          => s_axi_control_WSTRB_s,
    wvalid         => s_axi_control_WVALID_s,
    wready         => s_axi_control_WREADY_s,
    ------ write response signals
    bresp          => s_axi_control_BRESP_s,
    bvalid         => s_axi_control_BVALID_s,
    bready         => s_axi_control_BREADY_s,
    ------ AXI Lite read signals (not used)
    -------- read address signals
    araddr         => s_axi_control_ARADDR_s,
    arvalid        => s_axi_control_ARVALID_s,
    arready        => s_axi_control_ARREADY_s,
    ------ read data signals
    rdata          => s_axi_control_RDATA_s,
    rresp          => s_axi_control_RRESP_s,
    rvalid         => s_axi_control_RVALID_s,
    rready         => s_axi_control_RREADY_s
    -----------------------------------------------------------------------------
  );

  krdy_sync_unit: entity work.cross_clk_sync
  port map (
    clk_in           => ap_clk,
    reset_clkin_n    => ap_rst_n,
    clk_out          => aes_clk,
    reset_clkout_n   => aes_rstn_sync,
    data_i           => krdy,
    data_o           => krdy_sync 
  );  

  aes_start_sync_unit: entity work.cross_clk_sync
  port map (
    clk_in           => ap_clk,
    reset_clkin_n    => ap_rst_n,
    clk_out          => aes_clk,
    reset_clkout_n   => aes_rstn_sync,
    data_i           => aes_start,
    data_o           => aes_start_sync
  );  

  AES: entity work.AES_Comp
  port map (
    CLK  => aes_clk,
    EN   => one_const,
    RSTn => aes_rstn_sync,

    Kin  => key,
    Krdy => krdy_sync,
    Kvld => kvld,

    Din  => plaintext,
    Drdy => aes_start_sync,
    BSY  => aes_bsy,
    Dout => ciphertext,
    Dvld => aes_done
  );

  AxiBRAMFlusher: entity work.AxiFlusher
  generic map(
    BRAM_DATA_WIDTH => 512,
    BRAM_ADDR_WIDTH => log2(TRACE_BRAM_SIZE),
    WRITE_LENGTH    => N_SAMPLES
  )
  port map(
    base_ptr   => base_ptr,

    douta      => trace_bram_rdata,
    addra      => trace_bram_raddr,
    ena        => trace_bram_ren,

    start_dump => start_dump_sync,
    dump_idle  => dump_idle,

    aclk       => ap_clk,
    aresetn    => ap_rst_n,

    awaddr     => m_axi_bank_0_AWADDR_s,
    awlen      => m_axi_bank_0_AWLEN_s,
    awsize     => m_axi_bank_0_AWSIZE_s,
    awvalid    => m_axi_bank_0_AWVALID_s,
    awready    => m_axi_bank_0_AWREADY_s,

    wdata      => m_axi_bank_0_WDATA_s,
    wstrb      => m_axi_bank_0_WSTRB_s,
    wvalid     => m_axi_bank_0_WVALID_s,
    wlast      => m_axi_bank_0_WLAST_s,
    wready     => m_axi_bank_0_WREADY,

    bresp      => m_axi_bank_0_BRESP_s,
    bvalid     => m_axi_bank_0_BVALID_s,
    bready     => m_axi_bank_0_BREADY_s
  );

  dump_sync: entity work.cross_clk_sync
  port map (
    clk_in           => sens_clk,
    reset_clkin_n    => sens_rst_n,
    clk_out          => ap_clk,
    reset_clkout_n   => ap_rst_n,
    data_i           => start_dump,
    data_o           => start_dump_sync
  );

  sensors: entity work.sensor_top_multiple
  generic map (
    N_SENSORS      => N_SENSORS,
    COARSE_WIDTH   => IDC_SIZE,
    FINE_WIDTH     => IDF_SIZE,
    SENSOR_WIDTH   => SENSOR_WIDTH
  )
  port map (
    clk_in           => sens_clk,
    dlay_line_o      => sensor_val,
    sens_calib_clk   => ap_clk,
    sens_calib_val   => sens_calib_val,
    sens_calib_trg   => sens_calib_trg,
    sens_calib_id    => sens_calib_id

  );

  BramDumper: entity work.BramDumper
  generic map(
    IN_WIDTH        => 512,
    BRAM_DATA_WIDTH => 512,
    BRAM_ADDR_WIDTH => log2(TRACE_BRAM_SIZE),
    N_SAMPLES       => N_SAMPLES,
    BYTE_ADDR       => 0
  )
  port map(
    clk         => sens_clk,
    reset_n     => sens_rst_n,
    clk_en_p_i  => one_const,
    trigger_p_i => sens_trg,
    start_dump  => start_dump,
    bram_dump_idle => bram_dump_idle,
    data_i      => sensor_val_ext,
    data_o      => trace_bram_wdata,
    waddr_o     => trace_bram_waddr,
    strb_o      => trace_bram_wstrb,
    wen_o       => trace_bram_wen
  );
  pad_zeros: if N_SENSORS*SENSOR_WIDTH+32-1 < 511 generate
    sensor_val_ext(511 downto N_SENSORS*SENSOR_WIDTH+32) <= (others => '0');
  end generate;
  sensor_val_ext(N_SENSORS*SENSOR_WIDTH+32-1 downto 0) <= sensor_val;

  trace_bram: entity work.URAMLike
  generic map (
    DATA_WIDTH => 512,
    ADDR_WIDTH => log2(TRACE_BRAM_SIZE) 
  )
  port map (
    -- Dump trace port
    clka  => sens_clk,
    ena   => trace_bram_wen,
    wea   => trace_bram_wstrb,
    addra => trace_bram_waddr,
    dina  => trace_bram_wdata,
    -- Flush trace port
    clkb  => ap_clk,
    enb   => trace_bram_ren,
    addrb => trace_bram_raddr,
    doutb => trace_bram_rdata
  );

  sens_clk <= ap_clk;
  sens_rst_n <= ap_rst_n;
  ---- MMCM (additional clocks for CPU and sensor)
  clk_gen: entity work.clock_generator
  port map(
    aes_clk  => aes_clk,
    resetn   => ap_rst_n,
    locked   => locked,
    axi_clk  => ap_clk
  );

  reset_generator: rst_gen
  port map (
    slowest_sync_clk     => aes_clk,
    ext_reset_in         => aes_rstn,
    aux_reset_in         => one_const,
    mb_debug_sys_rst     => zero_const,
    dcm_locked           => locked,
    mb_reset             => open,
    bus_struct_reset     => open, 
    peripheral_reset     => open,
    interconnect_aresetn => open,
    peripheral_aresetn   => aes_rstn_sync 
  );

end struct;
