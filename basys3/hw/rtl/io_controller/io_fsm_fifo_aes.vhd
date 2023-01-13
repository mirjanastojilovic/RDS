-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library ieee;
use ieee.std_logic_1164.all;

------------
-- Entity --
------------
entity io_fsm is
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
  enc_i           : in  std_logic;
  trace_i         : in  std_logic;
  calib_i         : in  std_logic;
  restart_i       : in  std_logic;
  -- busy signals
  enc_bsy_i       : in  std_logic;
  dec_vld_i       : in  std_logic;
  uart_bsy_i      : in  std_logic;
  trace_bsy_i     : in  std_logic;
  -- FIFO signals
  c_fifo_empty_i  : in  std_logic;
  -- Control outputs --
  dec_start_o     : out std_logic;
  enc_start_o     : out std_logic;
  trenc_start_o   : out std_logic;
  addr_ok_o       : out std_logic;
  aes_rdy_o       : out std_logic;
  addr_n_en_o       : out std_logic;
  busy_o          : out std_logic;
  reset_n_o         : out std_logic;
  reset_addr_dec_o: out std_logic;
  -- flags
  aes_k_rdy_o     : out std_logic;
  aes_m_rdy_o     : out std_logic;
  aes_d_rdy_o     : out std_logic;
  calib_rdy_o     : out std_logic
  );
end entity io_fsm;

------------------
-- Architecture --
------------------
architecture behave of io_fsm is
  ------------------------------------
  -- Enumeration of possible states --
  ------------------------------------
  type state_t is (
  WAIT_K,
  ADDR_OK0,    
  WAIT_ADDR0,        
  DEC_START0, 
  RD_K,
  K_VLD,
  WAIT_MD,
  ADDR_OK1,
  WAIT_ADDR1,
  ADDR_OK2,
  WAIT_ADDR2,
  DEC_START1,
  RD_MASK,
  M_VLD,
  DEC_START2,
  RD_DATA,              
  D_VLD,
  WAIT_AES,
  AES_RDY_ST,
  AES_RDY_WAIT,
  WAIT_E,
  ADDR_OK3,
  WAIT_ADDR3,
  ENC_START,
  WR_E,  
  WAIT_TR, 
  ADDR_OK4,
  WAIT_ADDR4,
  TRENC_START,
  WR_TR,
  RESET0,
  RESET1,
  RESET2,
  UART_ACK0,
  UART_ACK1,
  UART_ACK2,
  UART_ACK3,
  UART_ACK4,
  UART_ACK_AES,
  ADDR_OK5,
  UART_ACK5,                  
  WAIT_ADDR5,
  DEC_START5,
  RD_CALIB,
  CALIB_VLD
  );

  signal state_curr_s     : state_t;
  
  signal reset_addr_dec_s : std_logic;

  begin
    STATE_DECODER: process (clk_i, n_reset)
    begin
      if(rising_edge(clk_i)) then
        if(n_reset = '0') then
          state_curr_s <= WAIT_K;
          dec_start_o     <= '0';
          enc_start_o     <= '0';
          trenc_start_o   <= '0';
          -- flags
          aes_k_rdy_o     <= '0';
          aes_m_rdy_o     <= '0';
          aes_d_rdy_o     <= '0';
          calib_rdy_o     <= '0';
          addr_ok_o       <= '0';
          aes_rdy_o       <= '0';
          addr_n_en_o     <= '0';
          reset_n_o         <= '1';
          reset_addr_dec_o<= '0';
        else
          dec_start_o     <= '0';
          enc_start_o     <= '0';
          trenc_start_o   <= '0';
          -- flags
          aes_k_rdy_o     <= '0';
          aes_m_rdy_o     <= '0';
          aes_d_rdy_o     <= '0';
          calib_rdy_o     <= '0';
          addr_ok_o       <= '0';
          aes_rdy_o       <= '0';
          addr_n_en_o     <= '0';
          reset_n_o       <= '1';
          reset_addr_dec_o<= '0';
          case state_curr_s is
            when WAIT_K =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                elsif key_i = '1' then
                  state_curr_s <= ADDR_OK0;
                elsif calib_i = '1' then
                   state_curr_s <= ADDR_OK5;
                else
                  state_curr_s <= WAIT_K;
                end if;
            when ADDR_OK0 =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                else
                  state_curr_s <= UART_ACK0;
                end if;
                addr_ok_o     <= '1';
            when UART_ACK0 =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                elsif(uart_bsy_i = '1') then
                  state_curr_s <= WAIT_ADDR0;
                  reset_addr_dec_o<= '1';
                else
                  state_curr_s <= UART_ACK0;
                end if;
            when WAIT_ADDR0 =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                elsif(uart_bsy_i = '1') then
                  state_curr_s <= WAIT_ADDR0;
                else
                  state_curr_s <= DEC_START0;
                end if;
            when DEC_START0 =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                else
                  state_curr_s <= RD_K;
                end if;
                dec_start_o     <= '1';
            WHEN RD_K =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                elsif (dec_vld_i = '1') then
                  state_curr_s <= K_VLD;
                else
                  state_curr_s <= RD_K;
                end if;
                addr_n_en_o <= '1';
            when K_VLD =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                else
                  state_curr_s <= WAIT_MD;
                end if;
                aes_k_rdy_o   <= '1';
            when WAIT_MD =>
                if(restart_i = '1') then
                  state_curr_s <= RESET0;
                elsif mask_i = '1' then
                  state_curr_s <= ADDR_OK1;
                elsif key_i = '1' then
                  state_curr_s <= WAIT_MD;
                elsif data_i = '1' then
                  state_curr_s <= ADDR_OK2;
                elsif enc_i = '1' then
                  state_curr_s <= WAIT_MD;
                elsif trace_i = '1' then
                  state_curr_s <= WAIT_MD;
                elsif calib_i = '1' then
                  state_curr_s <= ADDR_OK5;
                else
                  state_curr_s <= WAIT_MD;
                end if;
            when ADDR_OK1 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= UART_ACK1;
            end if;
            addr_ok_o     <= '1';
            when UART_ACK1 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR1;
              reset_addr_dec_o<= '1';
            else
              state_curr_s <= UART_ACK1;
            end if;
            when WAIT_ADDR1 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR1;
            else
              state_curr_s <= DEC_START1;
            end if;
            when ADDR_OK2 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= UART_ACK2;
            end if;
            addr_ok_o     <= '1';
            when UART_ACK2 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR2;
              reset_addr_dec_o<= '1';
            else
              state_curr_s <= UART_ACK2;
            end if;
            when WAIT_ADDR2 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR2;
            else
              state_curr_s <= DEC_START2;
            end if;
            when DEC_START1 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= RD_MASK;
            end if;
            dec_start_o     <= '1';
            when DEC_START2 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= RD_DATA;
            end if;
            dec_start_o     <= '1';
            when RD_MASK =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif (dec_vld_i = '1') then
              state_curr_s <= M_VLD;
            else
              state_curr_s <= RD_MASK;
            end if;
            addr_n_en_o <= '1';
            when RD_DATA =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif (dec_vld_i = '1') then
              state_curr_s <= D_VLD;
            else
              state_curr_s <= RD_DATA;
            end if;
            addr_n_en_o <= '1';
            when M_VLD =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= WAIT_MD;
            end if;
            aes_m_rdy_o   <= '1';
            when D_VLD =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= WAIT_AES;
            end if;
            aes_D_rdy_o   <= '1';
            when WAIT_AES =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(c_fifo_empty_i = '0' or trace_bsy_i = '1') then
              state_curr_s <= WAIT_AES;
            else
              state_curr_s <= AES_RDY_ST;
            end if;
            when AES_RDY_ST =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= UART_ACK_AES;
            end if;
            aes_rdy_o   <= '1';
            when UART_ACK_AES =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= AES_RDY_WAIT;
              reset_addr_dec_o<= '1';
            else
              state_curr_s <= UART_ACK_AES;
            end if;
            when AES_RDY_WAIT =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= AES_RDY_WAIT;
            else
              state_curr_s <= WAIT_E;
            end if;
            when WAIT_E =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(enc_i = '1') then
              state_curr_s <= ADDR_OK3;
            else
              state_curr_s <= WAIT_E;
            end if;
            when ADDR_OK3 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= UART_ACK3;
            end if;
            addr_ok_o     <= '1';
            when UART_ACK3 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR3;
              reset_addr_dec_o<= '1';
            else
              state_curr_s <= UART_ACK3;
            end if;
            when WAIT_ADDR3 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR3;
            else
              state_curr_s <= ENC_START;
            end if;
            when ENC_START =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= WR_E;
            end if;
            enc_start_o   <= '1';
            when WR_E =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif (enc_bsy_i = '0') then
              state_curr_s <= WAIT_TR;
            else
              state_curr_s <= WR_E;
            end if;
            when WAIT_TR =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(trace_i = '1') then
              state_curr_s <= ADDR_OK4;
            elsif (key_i = '1') then
              state_curr_s <= ADDR_OK0;
            else
              state_curr_s <= WAIT_TR;
            end if;
            when ADDR_OK4 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= UART_ACK4;
            end if;
            addr_ok_o     <= '1';
            when UART_ACK4 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR4;
              reset_addr_dec_o<= '1';
            else
              state_curr_s <= UART_ACK4;
            end if;
            when WAIT_ADDR4 =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(uart_bsy_i = '1') then
              state_curr_s <= WAIT_ADDR4;
            else
              state_curr_s <= TRENC_START;
            end if;
            when TRENC_START =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= WR_TR;
            end if;
            trenc_start_o <= '1';
            when WR_TR =>
            if(restart_i = '1') then
              state_curr_s <= RESET0;
            elsif(enc_bsy_i = '0') then
              state_curr_s <= WAIT_K;
            else
              state_curr_s <= WR_TR;
            end if;
            when ADDR_OK5 =>
              if(restart_i = '1') then
              state_curr_s <= RESET0;
            else
              state_curr_s <= UART_ACK5;
            end if;
              addr_ok_o     <= '1';
            when UART_ACK5 => 
              if(restart_i = '1') then
                state_curr_s <= RESET0;
              elsif(uart_bsy_i = '1') then
                state_curr_s <= WAIT_ADDR5;
                reset_addr_dec_o<= '1';
              else
                state_curr_s <= UART_ACK5;
              end if;
            when WAIT_ADDR5 =>
              if(restart_i = '1') then
                state_curr_s <= RESET0;
              elsif(uart_bsy_i = '1') then
                state_curr_s <= WAIT_ADDR5;
              else
                state_curr_s <= DEC_START5;
               end if;
            when DEC_START5 => 
               if(restart_i = '1') then
                 state_curr_s <= RESET0;
               else
                 state_curr_s <= RD_CALIB;
               end if;
               dec_start_o     <= '1';
            when RD_CALIB =>
               if(restart_i = '1') then
                 state_curr_s <= RESET0;
               elsif (dec_vld_i = '1') then
                 state_curr_s <= CALIB_VLD;
               else
                 state_curr_s <= RD_CALIB;
               end if;
               addr_n_en_o <= '1';
            when CALIB_VLD =>
               if(restart_i = '1') then
                 state_curr_s <= RESET0;
               else
                state_curr_s <= WAIT_K;
                end if;
               calib_rdy_o   <= '1';
            when RESET0 =>
            state_curr_s <= RESET1;
            reset_n_o       <= '0';
            when RESET1 =>
            state_curr_s <= RESET2;
            reset_n_o       <= '0';
            when RESET2 =>
            state_curr_s <= WAIT_K;
            reset_n_o       <= '0';
            when others =>
            null;
          end case;
        end if;
      end if;
    end process;
  end architecture behave;
