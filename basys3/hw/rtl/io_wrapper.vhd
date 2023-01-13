-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

	library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	--use IEEE.STD_LOGIC_UNSIGNED.ALL;
	-- Uncomment the following library declaration if using
	-- arithmetic functions with Signed or Unsigned values
	--use IEEE.NUMERIC_STD.ALL;
	
	-- Uncomment the following library declaration if instantiating
	-- any Xilinx leaf cells in this code.
	--library UNISIM;
	--use UNISIM.VComponents.all;
	
	entity io_wrapper is
	  Generic (
	    NUM_SAMPLE      : Positive := 256;
	    AES_DATA_LENGTH : Positive := 128;
	    SENSOR_DATA_LEN : Positive := 8;
	    SAMPLE_DATA_LEN : Positive := 16;
	    BRAM_ADDR_LEN   : Positive := 16;
	    CONF_RG_LEN     : Positive := 8;
	    CONF_RG_ADDR_LEN: Positive := 4;
	    UART_WORD_LEN   : Positive := 8;
	    BRAM_WORD_WIDTH : Positive := 144;
	    SENSOR_WIDTH    : Positive := 128
	  );
	  Port (
	    clk_ctrl_i      : in  std_logic;
	    clk_aes_i       : in  std_logic;
	    clk_trce_i      : in  std_logic;
	    clk_uart_i      : in  std_logic;
	    
	    reset_n_i       : in  std_logic;
	    reset_host_aes_i: in  std_logic;
	    reset_host_snsr_i: in std_logic;
	    
	    aes_D_i         : in  std_logic_vector(AES_DATA_LENGTH-1 downto 0);
	    aes_D_vld_i     : in  std_logic;
	    aes_busy_i      : in  std_logic;
	    
	    sensor_data_i   : in  std_logic_vector(SENSOR_WIDTH-1 downto 0);
	    start_rec_i     : in  std_logic;
	    temperature_i   : in STD_LOGIC_VECTOR(11 downto 0);
	    uart_rx_i       : in  std_logic;
	    uart_tx_o       : out std_logic;
	    
	    aes_D_o         : out std_logic_vector(AES_DATA_LENGTH-1 downto 0);
	    aes_D_rdy_o     : out std_logic;
	    aes_K_o         : out std_logic_vector(AES_DATA_LENGTH-1 downto 0);
	    aes_K_rdy_o     : out std_logic;
	    
	    calib_o         : out std_logic_vector(127 downto 0);
	    
	    conf_reg_o      : out std_logic_vector(CONF_RG_LEN-1 downto 0);
	    conf_reg_addr_o : out std_logic_vector(CONF_RG_ADDR_LEN-1 downto 0);
	    conf_reg_rdy_o  : out std_logic;
	    
	    reset_host_n_o    : out std_logic
	     );
	end io_wrapper;
	
	architecture Behavioral of io_wrapper is
	
	component BRAM_dual_clock is
	   generic(
	      DATA_WIDTH      : integer := BRAM_WORD_WIDTH;               
	      MEM_SIZE        : integer := NUM_SAMPLE;           
	      ADDR_WIDTH      : integer := BRAM_ADDR_LEN;       
	      OUT_LATENCY     : string  := "ONE_CYCLE";   
	      C_INIT_FILE     : string  := "NO_INIT_FILE"
	      );
	  port(
	    clk_a : IN STD_LOGIC;
	    clk_b : IN STD_LOGIC;
	
	    ena    : IN STD_LOGIC;
	    regcea : IN STD_LOGIC; 
	    rsta   : IN STD_LOGIC;
	
	    wea    : IN  STD_LOGIC;
	    dina   : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1  DOWNTO 0);
	    addra  : IN  STD_LOGIC_VECTOR(ADDR_WIDTH-1  DOWNTO 0);
	    douta  : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1  DOWNTO 0);
	
	
	    enb    : IN STD_LOGIC;
	    regceb : IN STD_LOGIC; 
	    rstb   : IN STD_LOGIC;
	
	    web    : IN  STD_LOGIC;
	    dinb   : IN  STD_LOGIC_VECTOR(DATA_WIDTH-1  DOWNTO 0);
	    addrb  : IN  STD_LOGIC_VECTOR(ADDR_WIDTH-1  DOWNTO 0);
	    doutb  : OUT STD_LOGIC_VECTOR(DATA_WIDTH-1  DOWNTO 0)
	  );
	end component;
	
	component fifo_generator_0
	    port (
	        wr_clk              : IN STD_LOGIC;
	        wr_rst              : IN STD_LOGIC;
	        rd_clk              : IN STD_LOGIC;
	        rd_rst              : IN STD_LOGIC;
	        din                 : IN STD_LOGIC_VECTOR(AES_DATA_LENGTH-1 DOWNTO 0);
	        wr_en               : IN STD_LOGIC;
	        rd_en               : IN STD_LOGIC;
	        dout                : OUT STD_LOGIC_VECTOR(AES_DATA_LENGTH-1 DOWNTO 0);
	        full                : OUT STD_LOGIC;
	        wr_ack              : OUT STD_LOGIC;
	        empty               : OUT STD_LOGIC;
	        valid               : OUT STD_LOGIC
	    );
	end component;
	
	COMPONENT io_controller is
	    Generic (
	        AES_DATA_LEN      : Positive := AES_DATA_LENGTH;
	        NUM_SAMPLES       : Positive := NUM_SAMPLE;
	        BRAM_ADDR_LEN     : Positive := BRAM_ADDR_LEN;
	        SAMPLE_DATA_LEN   : Positive := SAMPLE_DATA_LEN;
	        CONF_RG_LEN       : Positive := 8;
	        CONF_RG_ADDR_LEN  : Positive := 4;
	        UART_WORD_LEN     : Positive := UART_WORD_LEN;
	        BRAM_WORD_WIDTH   : Positive := BRAM_WORD_WIDTH
	        
	    );
	    Port (
	       clk_i                : in  std_logic;
	       n_reset              : in  std_logic;
	
	       aes_D_i              : in  std_logic_vector (AES_DATA_LEN-1 downto 0);
	       aes_D_rdy_i          : in  std_logic;
	       bram_D_i             : in  std_logic_vector(BRAM_WORD_WIDTH-1 downto 0);
	       addr_bram_o          : out std_logic_vector(BRAM_ADDR_LEN-1 downto 0);
	       trace_bsy_i          : in  std_logic;
	       c_fifo_empty_i       : in  std_logic;
	       aes_D_o              : out std_logic_vector (AES_DATA_LEN-1 downto 0);
	       aes_D_rdy_o          : out std_logic;
	       aes_K_o              : out std_logic_vector(AES_DATA_LEN-1 downto 0);
	       aes_K_rdy_o          : out std_logic;
	       calib_o              : out std_logic_vector(127 downto 0);

	       reg_addr_o           : out std_logic_vector(CONF_RG_ADDR_LEN-1 downto 0);
	       reg_data_o           : out std_logic_vector(CONF_RG_LEN-1 downto 0);
	       reg_data_rdy_o       : out std_logic;
	       
	       uart_word_i          : in  std_logic_vector(UART_WORD_LEN-1 downto 0);
	       uart_word_o          : out std_logic_vector(UART_WORD_LEN-1 downto 0);
	       uart_rx_vld_i        : in  std_logic;
	       uart_tx_start_o      : out std_logic;
	       uart_tx_bsy_i        : in  std_logic;
	       reset_n_o            : out std_logic
	       );
	end COMPONENT;
	
	component FSM_FIFO is
	    Port ( 
	       clk_i                : in STD_LOGIC;
	       reset_n_i            : in STD_LOGIC;
	       fifo_empty_i         : in STD_LOGIC;
	       reader_bsy_i         : in STD_LOGIC;
	       rinc_o               : out STD_LOGIC;
	       data_vld_o           : out STD_LOGIC
	     );
	end component;
	
	COMPONENT UART is
	    Generic (
	        WORD_WIDTH      : Positive := UART_WORD_LEN
	    );
	    Port (
	        clk                 : in STD_LOGIC;
	        tx_start_i          : in STD_LOGIC;
	        data_i              : in STD_LOGIC_VECTOR (WORD_WIDTH-1 downto 0);
	        data_o              : out STD_LOGIC_VECTOR (WORD_WIDTH-1 downto 0);
	        rx_vld_o            : out STD_LOGIC;
	        tx_bsy_o            : out STD_LOGIC;
	        rx                  : in STD_LOGIC;
	        tx                  : out STD_LOGIC
	        );
	end COMPONENT;
	
	component read_traces is
	    generic (
	        NUM_SAMPLE      : Positive := NUM_SAMPLE;
	        SAMPLE_WIDTH    : Positive := SENSOR_DATA_LEN;
	        BRAM_ADDR_WIDTH : Positive := BRAM_ADDR_LEN;
	        BRAM_WORD_WIDTH : Positive := BRAM_WORD_WIDTH;
	        SENSOR_WIDTH    : Positive := SENSOR_WIDTH
	        
	    );
	    Port (
	        clk_i               : in STD_LOGIC;
	        n_reset_i           : in STD_LOGIC;
	        start_i             : in STD_LOGIC;
	        sensor_data_i       : in STD_LOGIC_VECTOR (SENSOR_WIDTH-1 downto 0);
	        temperature_i_s     : in STD_LOGIC_VECTOR(11 downto 0);
	        en_o                : out STD_LOGIC;
	        data_o              : out STD_LOGIC_VECTOR (BRAM_WORD_WIDTH-1 downto 0);
	        addr_o              : out STD_LOGIC_VECTOR (BRAM_ADDR_WIDTH-1 downto 0)
	    );
	end component;

	signal rx_s                 : std_logic;
	signal tx_s                 : std_logic;
	signal tx_start_s           : std_logic;
	signal rx_vld_s             : std_logic;
	signal tx_bsy_s             : std_logic;
	signal uart_data_is         : std_logic_vector(UART_WORD_LEN-1 downto 0);
	signal uart_data_os         : std_logic_vector(UART_WORD_LEN-1 downto 0);
	signal aes_C_is             : std_logic_vector(AES_DATA_LENGTH-1 downto 0);
	signal c_fifo_data_vld_s    : std_logic;
	signal c_fifo_empty         : std_logic;
	signal wr_tr_addr_os        : std_logic_vector(BRAM_ADDR_LEN-1 downto 0);
	signal wr_tr_data_is        : std_logic_vector(BRAM_WORD_WIDTH-1 downto 0);
	signal aes_D_os             : std_logic_vector(AES_DATA_LENGTH-1 downto 0);
	signal io_aes_D_rdy_s       : std_logic;
	signal aes_K_os             : std_logic_vector(AES_DATA_LENGTH-1 downto 0);
	signal aes_K_rdy_s          : std_logic;
	signal io_uart_word_os      : std_logic_vector(UART_WORD_LEN-1 downto 0);
	signal io_tx_start_os       : std_logic;
	signal rd_tr_en_os          : std_logic;
	signal rd_tr_data_os        : std_logic_vector(BRAM_WORD_WIDTH-1 downto 0);
	signal rd_tr_addr_os        : std_logic_vector(BRAM_ADDR_LEN-1 downto 0);
	signal fsm_state_s          : std_logic_vector(7 downto 0);
	
	 
	-- FIFOs
	-- AES Key FIFO & FSM
	signal km_fifo_data_vld_s   : std_logic;
	signal km_fifo_rinc         : std_logic;
	signal km_fifo_empty        : std_logic;
	signal km_fifo_wrack        : std_logic;
	signal km_fifo_valid        : std_logic;
	-- AES Plaintext FIFO & FSM  
	signal d_fifo_data_vld_s    : std_logic;
	signal d_fifo_rinc          : std_logic;
	signal d_fifo_empty         : std_logic;
	signal d_fifo_wrack         : std_logic;
	signal d_fifo_valid         : std_logic;
	-- AES Cipher FIFO & FSM    
	signal  c_fifo_rinc         : std_logic;
	signal  c_fifo_wrack        : std_logic;
	signal c_fifo_valid         : std_logic;
	-- Dual-clock BRAM signal
	signal dc_br_worda_os       : std_logic_vector(BRAM_WORD_WIDTH-1 downto 0);
	-- Active High reset signals
	signal reset_p_s            : std_logic;
	signal reset_host_aes_p_s   : std_logic;
	signal reset_host_snsr_p_s  : std_logic;
	-- trigger signal
	signal start_rec_delayed : std_logic;
	
	
	BEGIN
	
	reset_p_s           <= not reset_n_i;
	reset_host_aes_p_s  <= not reset_host_aes_i;
	reset_host_snsr_p_s <= not reset_host_snsr_i;
	
	io_ctrl: io_controller
	    Port MAP (
	        clk_i           => clk_ctrl_i,
	        n_reset         => reset_n_i,
	        
	        aes_D_i         => aes_C_is,
	        aes_D_rdy_i     => c_fifo_data_vld_s,
	        trace_bsy_i     => rd_tr_en_os,
	        bram_D_i        => wr_tr_data_is,
	        addr_bram_o     => wr_tr_addr_os,
	
	        aes_D_rdy_o     => io_aes_D_rdy_s,
	        aes_D_o         => aes_D_os,
	        aes_K_o         => aes_K_os,
	        aes_K_rdy_o     => aes_K_rdy_s,
	        calib_o         => calib_o,
	        reg_addr_o      => conf_reg_addr_o,
	        reg_data_o      => conf_reg_o,
	        reg_data_rdy_o=> conf_reg_rdy_o,
	        c_fifo_empty_i  => c_fifo_empty, 
	        
	        uart_word_i     => uart_data_os,
	        uart_word_o     => io_uart_word_os,
	        uart_rx_vld_i   => rx_vld_s,
	        uart_tx_start_o => io_tx_start_os,
	        uart_tx_bsy_i   => tx_bsy_s,
	        reset_n_o       => reset_host_n_o
	   );
	
	
	rd_tr: read_traces
	    port map (
	       clk_i            => clk_trce_i,
	       n_reset_i        => reset_host_snsr_i,
	       start_i          => start_rec_i,
	       sensor_data_i    => sensor_data_i,
	       temperature_i_s  => temperature_i,
	       en_o             => rd_tr_en_os,
	       data_o           => rd_tr_data_os,
	       addr_o           => rd_tr_addr_os
	   );
	
	KM_fifo: fifo_generator_0
	    port map (
	        wr_rst  => reset_p_s,
	        rd_rst  => reset_host_aes_p_s,
	        din     => aes_K_os,
	        wr_en   => aes_K_rdy_s,
	        empty   => km_fifo_empty,
	        dout    => aes_K_o,
	        rd_en   => km_fifo_rinc,
	        wr_clk  => clk_ctrl_i,
	        rd_clk  => clk_aes_i,
	        wr_ack  => km_fifo_wrack,
	        valid   => km_fifo_valid
	    );
	
	
	 KM_FIFO_FSM: FSM_FIFO
	    port map (
	        clk_i       => clk_aes_i,
	        reset_n_i   => reset_host_aes_i,
	        fifo_empty_i=> km_fifo_empty,
	        reader_bsy_i=> aes_busy_i,
	        rinc_o      => km_fifo_rinc,
	        data_vld_o  => aes_K_rdy_o
	    );
	
	D_fifo: fifo_generator_0
	    port map (
	        wr_rst  => reset_p_s,
	        rd_rst  => reset_host_aes_p_s,
	        din     => aes_D_os,
	        wr_en   => io_aes_D_rdy_s,
	        empty   => d_fifo_empty,
	        dout    => aes_D_o,
	        rd_en   => d_fifo_rinc,
	        wr_clk  => clk_ctrl_i,
	        rd_clk  => clk_aes_i,
	        wr_ack  => d_fifo_wrack,
	        valid   => d_fifo_valid
	    );
	
	D_FIFO_FSM: FSM_FIFO
	    port map (
	        clk_i       => clk_aes_i,
	        reset_n_i   => reset_host_aes_i,
	        fifo_empty_i=> d_fifo_empty,
	        reader_bsy_i=> aes_busy_i,
	        rinc_o      => d_fifo_rinc,
	        data_vld_o  => aes_D_rdy_o
	    );
	   
	
	C_fifo: fifo_generator_0
	    port map (
	        wr_rst  => reset_host_aes_p_s,
	        rd_rst  => reset_p_s,
	        din     => aes_D_i,
	        wr_en   => aes_D_vld_i,
	        empty   => c_fifo_empty,
	        dout    => aes_C_is,
	        rd_en   => c_fifo_rinc,
	        wr_clk  => clk_aes_i,
	        rd_clk  => clk_ctrl_i,
	        wr_ack  => c_fifo_wrack,
	        valid   => c_fifo_valid
	    
	    );
	
	 C_FIFO_FSM: FSM_FIFO
	    port map (
	        clk_i       => clk_ctrl_i,
	        reset_n_i   => reset_n_i,
	        fifo_empty_i=> c_fifo_empty,
	        reader_bsy_i=> '0',
	        rinc_o      => c_fifo_rinc,
	        data_vld_o  => c_fifo_data_vld_s
	    );
	
	  uart_data_is <= io_uart_word_os;
	
	  tx_start_s <= io_tx_start_os;
	  
	  DC_BR : BRAM_dual_clock
	    port map (
	        clk_a           => clk_trce_i,
	        clk_b           => clk_ctrl_i,
	
	        ena             => rd_tr_en_os,
	        regcea          => '0',
	        rsta            => reset_host_snsr_p_s,
	
	        wea             => rd_tr_en_os,
	        dina            => rd_tr_data_os,
	        addra           => rd_tr_addr_os,
	        douta           => dc_br_worda_os,
	
	
	        enb             => '1', 
	        regceb          => '0',
	        rstb            => reset_p_s,
	
	        web             => '0',
	        dinb            => (others => '0'),
	        addrb           => wr_tr_addr_os,
	        doutb           => wr_tr_data_is
	    );
	
	uart_0: UART
	    port map(
	        clk           => clk_uart_i,
	        tx_start_i    => tx_start_s,
	        data_i        => uart_data_is,
	        data_o        => uart_data_os,
	        rx_vld_o      => rx_vld_s,
	        tx_bsy_o      => tx_bsy_s,
	        rx            => rx_s,
	        tx            => tx_s
	    );
	
	  rx_s <= uart_rx_i;
	  
	  uart_tx_o <= tx_s;
	
	end Behavioral;
