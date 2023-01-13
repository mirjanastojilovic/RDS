-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity io_controller is
    Generic (
        AES_DATA_LEN      : Positive := 128;
        NUM_SAMPLES       : Positive := 256;
        BRAM_ADDR_LEN     : Positive := 16;
        BRAM_WORD_LEN     : Positive := 144;
        SAMPLE_DATA_LEN   : Positive := 16;
        CONF_RG_LEN       : Positive := 8;
        CONF_RG_ADDR_LEN  : Positive := 4;
        UART_WORD_LEN     : Positive := 8;
        SENSOR_WIDTH      : Positive := 128
    );
    Port ( clk_i : in STD_LOGIC;
           n_reset : in STD_LOGIC;

           aes_D_i : in STD_LOGIC_VECTOR (127 downto 0);
           bram_D_i : in std_logic_vector(BRAM_WORD_LEN-1 downto 0);

           addr_bram_o : out std_logic_vector(BRAM_ADDR_LEN-1 downto 0);
           aes_D_rdy_i : in STD_LOGIC;
           trace_bsy_i     : in  std_Logic;
               -- FIFO signals
            c_fifo_empty_i  : in  std_logic;

           aes_D_rdy_o : out STD_LOGIC;
           aes_D_o : out STD_LOGIC_VECTOR (127 downto 0);
           aes_K_o : out STD_LOGIC_VECTOR(127 downto 0);
           calib_o : out STD_LOGIC_VECTOR(127 downto 0);
           aes_K_rdy_o : out STD_LOGIC;
           -- control registers 
           reg_addr_o     : out std_logic_vector(3 downto 0);
           reg_data_o       : out std_logic_vector(7 downto 0);
           reg_data_rdy_o   : out std_logic;
           -- uart signals
           uart_word_i : in STD_LOGIC_VECTOR(7 downto 0);
           uart_word_o : out STD_LOGIC_VECTOR(7 downto 0);
           uart_rx_vld_i : in std_logic;
           uart_tx_start_o : out std_logic;
           uart_tx_bsy_i : in std_logic;
           reset_n_o    : out std_logic
           );
end io_controller;

architecture Behavioral of io_controller is

component counter_up is
			generic (
				SIZE : positive := AES_DATA_LEN/UART_WORD_LEN
			);
			port (
				n_reset_i : in std_logic;
				clk_i : in std_logic;
				load_i : in std_logic; -- prioritized load command --
				up_i : in std_logic; -- increment command --
				val_i : in std_logic_vector(SIZE - 1 downto 0);
				val_o : out std_logic_vector(SIZE - 1 downto 0)
			);
		end component;

   COMPONENT address_dec is
    Port (
    clk_i       : in std_logic;
    addr_rdy_i  : in std_logic;
    addr_i      : in std_logic_vector(7 downto 0);
    n_en_i      : in std_Logic;
    rst_output  : in std_logic;
    key_o       : out std_logic;
    mask_o      : out std_logic;
    data_o      : out std_logic;
    enc_o       : out std_logic;
    trace_o     : out std_logic;
    calib_o     : out std_logic;
    reg_update_o: out std_logic;
    addr_o      : out std_logic_vector(7 downto 0);
    restart_o   : out std_logic
    );
    end COMPONENT;

    COMPONENT io_fsm is
    port (
        -- Asynchronous actions --
        n_reset         : in  std_logic;
        -- Dynamic actions --
        clk_i             : in  std_logic;
        -- Control inputs --
        -- address flags
        key_i           : in  std_logic;
        mask_i          : in  std_logic;
        data_i          : in  std_logic;
        trace_i         : in  std_logic;
        enc_i           : in  std_logic;
        calib_i         : in  std_logic;
        restart_i       : in  std_logic;
        -- busy signals
        enc_bsy_i       : in  std_logic;
        dec_vld_i       : in  std_logic;
        uart_bsy_i      : in  std_Logic;
        trace_bsy_i     : in  std_logic;
        -- FIFO signals
        c_fifo_empty_i  : in  std_logic;
        -- Control outputs --
        dec_start_o     : out std_logic;
        enc_start_o     : out std_logic;
        trenc_start_o   : out std_logic;
        busy_o          : out std_logic;
        addr_n_en_o     : out std_logic;
        reset_addr_dec_o: out std_logic;
        -- flags
        aes_k_rdy_o     : out std_logic;
        aes_m_rdy_o     : out std_logic;
        aes_d_rdy_o     : out std_logic;
        addr_ok_o       : out std_logic;
        aes_rdy_o       : out std_logic;
        calib_rdy_o     : out std_logic;
        reset_n_o         : out std_logic
    );
    end COMPONENT;

    COMPONENT  data_dec is
    generic (
    AES_DATA_LEN      : Positive := AES_DATA_LEN;
    UART_WORD_LEN     : Positive := UART_WORD_LEN
    );
    port (clk_i               : in std_logic;
          n_reset_i           : in std_logic;
          data_rdy_i          : in std_logic;
          start_dec_i         : in std_logic;
          word_i              : in std_logic_vector(UART_WORD_LEN-1 downto 0);

          data_vld_o          : out std_logic;
          data_o              : out std_logic_vector(AES_DATA_LEN-1 downto 0)
    );
    end COMPONENT;

    COMPONENT data_enc is
    generic (
        NUM_SAMPLES       : Positive := NUM_SAMPLES;
        AES_DATA_LEN      : Positive := AES_DATA_LEN;
        BRAM_ADDR_LEN     : Positive := BRAM_ADDR_LEN;
        BRAM_WORD_LEN     : Positive := BRAM_WORD_LEN;
        SAMPLE_DATA_LEN   : Positive := SAMPLE_DATA_LEN;
        UART_WORD_LEN     : Positive := UART_WORD_LEN;
        SENSOR_WIDTH      : Positive := SENSOR_WIDTH
     );
      port (
        clk_i               : in std_logic;
        n_reset_i           : in std_logic;
    
        start_enc_i         : in std_logic;
        start_tr_i          : in STD_LOGIC;
    
        ciph_vld_i          : in std_logic;
        uart_bsy_i          : in std_logic;
        aes_data_i          : in std_logic_vector(AES_DATA_LEN-1 downto 0);
    
        tr_data_i           : in STD_LOGIC_VECTOR (BRAM_WORD_LEN-1 downto 0);
    
        addr_o              : out STD_LOGIC_VECTOR (BRAM_ADDR_LEN-1 downto 0);
        busy_o              : out std_logic;
        word_vld_o          : out std_logic;
        word_o              : out std_logic_vector(UART_WORD_LEN-1 downto 0)
        );
    end COMPONENT;
    
    component config_registers is
      port (
        clk_i       : in STD_LOGIC;
        reset_n     : in STD_LOGIC;
        addr_i      : in STD_LOGIC_VECTOR (3 downto 0);
        addr_vld_i  : in STD_LOGIC;
        uart_data_i : in STD_LOGIC_VECTOR (7 downto 0);
        uart_vld_i  : in STD_LOGIC;
        addr_o      : out STD_LOGIC_VECTOR (3 downto 0);
        data_o      : out STD_LOGIC_VECTOR (7 downto 0);
        rd_en_o     : out std_logic;
        data_rdy_o  : out STD_LOGIC
        );
    end component;


    signal aes_D_rdy_os,tx_start_s, rx_vld_s, tx_bsy_s, trenc_bsy_s, trenc_en_s, key_rdy_s, data_vld_s : std_logic;
    signal data_o_s, msr_o_s, addr_en_s, d_rd_en_s, d_wr_en_s, msr_wr_en_s, data_enc_en_s : std_logic;
    signal data_i_s, key_i_s, calib_i_s, d_rd_i_s, d_wr_i_s, msr_wr_i_s, mask_i_s, byte_n_word_s, restart_s : std_logic;
    signal addr_rdy_s, dec_bsy_s, enc_bsy_s, enc_vld_s, trenc_vld_s, dec_vld_s, uart_bsy_s, uart_vld_s : std_logic;
    signal trenc_data_is, denc_data_is, data_is, data_os, data_enc_s, addr_s, uart_word_os, uart_word_or : std_logic_vector(7 downto 0);
    signal data_dec_o_s, data_enc_i_s, aes_D_o_r, aes_K_o_r, aes_D_o_s, aes_K_o_s : std_logic_vector(127 downto 0);
    signal calib_o_s, calib_o_r : std_logic_vector(127 downto 0);
    signal dec_start_s,enc_start_s, trenc_start_s,trenc_start_k, busy_s,aes_k_rdy_s, aes_m_rdy_s,  aes_d_rdy_s : std_logic;
    signal combined_reset, num_tr_start_s, num_tr_s : std_logic;
    signal addr_ack_s, dec_ack_s, uart_ack_s, uart_en_n_s: std_logic;
    signal km_fifo_empty_s, d_fifo_empty_s, c_fifo_empty_s : std_logic;
    signal addr_ok_s, reset_n_s, reset_n, addr_n_en_s, aes_rdy_s,calib_rdy_s : std_logic;
    signal addr_out_os              : std_logic_vector(6 downto 0);
    signal aes_D_rdy_is, aes_D_rdy_ir : std_logic;
    signal trace_bsy_async, trace_bsy_meta, trace_bsy_synced, clear_s : std_logic;
    signal reg_addr_s   : std_logic_vector(3 downto 0);
    signal reg_update_s, reg_en_s : std_logic;
    signal addr_dec_n_en        : std_logic;
    signal reset_addr_dec_s : std_logic;
    signal start_enc_counter : std_logic_vector(15 downto 0) := "0000000000000000";

    signal start_tr_s : std_logic;
    
    signal trace_cntr_ld_r : std_logic;
    signal trace_cntr_up_r : std_logic;
    signal first_byte : std_logic := '0';
    signal counter_os : std_logic_vector(15 downto 0);
    signal count : std_logic_vector(15 downto 0) := X"0000";

begin


  reset_n <= '1' when n_reset = '1' and reset_n_s = '1' else
             '0';
             
  addr_dec_n_en <= '1' when addr_n_en_s = '1' else
                   '1' when reg_en_s = '1' else
                   '0';

  addr_decoder: address_dec
  port map (
    clk_i         => clk_i,
    addr_rdy_i    => uart_rx_vld_i,
    addr_i        => uart_word_i,
    n_en_i        => addr_dec_n_en,
    rst_output    => reset_addr_dec_s,
    key_o         => key_i_s,
    mask_o        => mask_i_s,
    data_o        => data_i_s,
    enc_o         => data_o_s,
    trace_o       => msr_o_s,
    calib_o       => calib_i_s,
    reg_update_o  => reg_update_s,
    addr_o        => addr_s,
    restart_o     => restart_s
    );
    
    config_regs: config_registers
    port map (
      clk_i      => clk_i,
      reset_n    => reset_n,
      addr_vld_i => reg_update_s,
      addr_i     => addr_s(3 downto 0),
      uart_data_i=> uart_word_i,
      uart_vld_i => uart_rx_vld_i,
      addr_o     => reg_addr_o,
      data_o     => reg_data_o,
      rd_en_o    => reg_en_s,
      data_rdy_o => reg_data_rdy_o
    );

    trace_bsy_sync:process(clk_i, n_reset, trace_bsy_i, trace_bsy_async, trace_bsy_meta)
    begin
         if(rising_edge(clk_i))then
             if(n_reset = '0') then
                 trace_bsy_async <= '0';
                 trace_bsy_meta <= '0';
                 trace_bsy_synced <= '0';
             else
                 trace_bsy_async <= trace_bsy_i;
                 trace_bsy_meta  <= trace_bsy_async;
                 trace_bsy_synced <= trace_bsy_meta;
             end if;
         end if;
    end process;

trenc_start_k <= trenc_start_s;

  ctrl: io_fsm
  port map(
    clk_i         => clk_i,
    n_reset       => n_reset,
    key_i         => key_i_s,
    mask_i        => mask_i_s,
    data_i        => data_i_s,
    calib_i       => calib_i_s,
    trace_i       => msr_o_s,
    enc_i         => data_o_s,
    restart_i     => restart_s,
    c_fifo_empty_i => c_fifo_empty_i,
    trace_bsy_i  => trace_bsy_synced,
    enc_bsy_i     => enc_bsy_s,
    dec_vld_i     => dec_vld_s,
    uart_bsy_i    => uart_tx_bsy_i,

    dec_start_o   => dec_start_s,
    enc_start_o   => enc_start_s,
    trenc_start_o => trenc_start_s,
    busy_o        => busy_s,
    addr_n_en_o     => addr_n_en_s,
    reset_addr_dec_o => reset_addr_dec_s,
    aes_k_rdy_o   => aes_k_rdy_s,
    aes_m_rdy_o   => aes_m_rdy_s,
    aes_d_rdy_o   => aes_d_rdy_s,
    addr_ok_o     => addr_ok_s,
    aes_rdy_o     => aes_rdy_s,
    calib_rdy_o   => calib_rdy_s,
    reset_n_o     => reset_n_s
    );

  data_decoder:  data_dec
  port map (
    clk_i           => clk_i,
    n_reset_i       => reset_n,
    start_dec_i     => dec_start_s,
    data_rdy_i      => uart_rx_vld_i,
    word_i          => uart_word_i,

    data_vld_o      => dec_vld_s,
    data_o          => data_dec_o_s
    );

  data_encoder: data_enc
  port map(
    clk_i           => clk_i,
    n_reset_i       => reset_n,
    start_enc_i     => enc_start_s,
    uart_bsy_i      => uart_tx_bsy_i,
    start_tr_i      => trenc_start_k,
    aes_data_i      => aes_D_i,

    tr_data_i       => bram_D_i,
    ciph_vld_i      => aes_D_rdy_i,
    busy_o          => enc_bsy_s,
    word_vld_o      => enc_vld_s,
    word_o          => denc_data_is,
    addr_o          => addr_bram_o
    );

  registers: process(clk_i, n_reset)
  begin

    if(rising_edge(clk_i)) then
        if(n_reset = '0') then
        aes_D_o_r <= X"00000000000000000000000000000000";
        aes_K_o_r <= X"00000000000000000000000000000000";
        calib_o_r <= X"00000000000000000000000000000000";
        uart_word_or <= (others => '0');
        else
        aes_D_o_r <= aes_D_o_s;
        aes_K_o_r <= aes_K_o_s;
        uart_word_or <= uart_word_os;
        calib_o_r   <= calib_o_s;
        end if;
    end if;
  end process;

cntr : counter_up
    generic map(SIZE => 16)
    port map(
        n_reset_i => n_reset,
        clk_i => clk_i,
        load_i => trace_cntr_ld_r,
        up_i => trace_cntr_up_r,
        val_i => (others => '0'),
        val_o => counter_os
    );

  -- Combinational signals
  uart_word_os     <= denc_data_is when enc_vld_s = '1' else
                      addr_s       when addr_ok_s = '1' else
                      X"42"        when aes_rdy_s = '1' else
                      uart_word_or;

  uart_word_o       <= uart_word_os;

  reset_n_o         <= reset_n_s;


  uart_tx_start_o <= '1' when enc_vld_s = '1'  else
                     '1' when addr_ok_s = '1' else
                     '1' when aes_rdy_s = '1' else
                     '0';

  aes_K_o_s   <=  data_dec_o_s when aes_k_rdy_s = '1' or aes_m_rdy_s = '1' else
                  aes_K_o_r;
  aes_D_o_s   <=  data_dec_o_s when aes_d_rdy_s = '1' else
                  aes_D_o_r;
                  
  aes_D_rdy_o <= aes_d_rdy_s;

  calib_o_s   <= data_dec_o_s when calib_rdy_s = '1' else calib_o_r;
  -- Outputs
  aes_D_o     <=  aes_D_o_s;
  aes_K_o     <=  aes_K_o_s;
  calib_o     <= calib_o_s;
  aes_K_rdy_o <= '1' when aes_k_rdy_s = '1' or aes_m_rdy_s = '1' else
               '0';
end Behavioral;

