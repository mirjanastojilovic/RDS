-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.all;
	use work.design_package.all;
	
	entity data_enc is
		generic (
			NUM_SAMPLES : positive := 256;
			AES_DATA_LEN : positive := 128;
			BRAM_ADDR_LEN : positive := 16;
			BRAM_WORD_LEN : positive := 144;
			SAMPLE_DATA_LEN : positive := 16;
			UART_WORD_LEN : positive := 8;
			SENSOR_WIDTH : positive := 128
		);
		port (
			clk_i : in std_logic;
			n_reset_i : in std_logic;
	
			start_enc_i : in std_logic;
			start_tr_i : in STD_LOGIC;
	
			ciph_vld_i : in std_logic;
			uart_bsy_i : in std_logic;
			aes_data_i : in std_logic_vector(AES_DATA_LEN - 1 downto 0);
	
			tr_data_i : in STD_LOGIC_VECTOR (BRAM_WORD_LEN - 1 downto 0);
	
			addr_o : out STD_LOGIC_VECTOR (BRAM_ADDR_LEN - 1 downto 0);
			busy_o : out std_logic;
			word_vld_o : out std_logic;
			word_o : out std_logic_vector(UART_WORD_LEN - 1 downto 0)
		);
	end data_enc;
	
	architecture behave of data_enc is
	
		component counter_up is
			generic (
				SIZE : positive := AES_DATA_LEN/UART_WORD_LEN
			);
			port (
				n_reset_i : in std_logic;
				clk_i : in std_logic;
				load_i : in std_logic; 
				up_i : in std_logic; 
				val_i : in std_logic_vector(SIZE - 1 downto 0);
				val_o : out std_logic_vector(SIZE - 1 downto 0)
			);
		end component;
	
	
		-- internal stuff
		constant num_sample : std_logic_vector(BRAM_ADDR_LEN - 1 downto 0) := std_logic_vector(to_unsigned(num_samples, 16));
		constant cipher_nbyte : std_logic_vector(log2(AES_DATA_LEN/UART_WORD_LEN) downto 0) := std_logic_vector(to_unsigned(AES_DATA_LEN/UART_WORD_LEN, 5));
		constant ZEROS : std_logic_vector(word_o'range) := (others => '0');
	
		signal ciph_is : std_logic_vector(aes_data_i'range);
		signal ciph_ir : std_logic_vector(aes_data_i'range);
	
		signal addr_os : std_logic_vector(BRAM_ADDR_LEN - 1 downto 0);
		signal counter_os : std_logic_vector(log2(AES_DATA_LEN/UART_WORD_LEN) downto 0);
	
		signal num_done : std_Logic;
	
		type ciph_state_t is (
		IDLE,
		START_TRANS,
		WR_BYTE,
		UART_ACK,
		UART_WAIT,
		BYTE_DONE,
		DONE
		);
	
		type trace_state_t is (
		IDLE,
		START_TRANS,
		WR_BYTE0,
		UART_ACK0,
		UART_WAIT0,
		WR_BYTE1,
		UART_ACK1,
		UART_WAIT1,
		WR_BYTE2,
		UART_ACK2,
		UART_WAIT2,
		WR_BYTE3,
		UART_ACK3,
		UART_WAIT3,
		WR_BYTE4,
		UART_ACK4,
		UART_WAIT4,
		WR_BYTE5,
		UART_ACK5,
		UART_WAIT5,
		WR_BYTE6,
		UART_ACK6,
		UART_WAIT6,
		WR_BYTE7,
		UART_ACK7,
		UART_WAIT7,
		WR_BYTE8,
		UART_ACK8,
		UART_WAIT8,
		WR_BYTE9,
		UART_ACK9,
		UART_WAIT9,
		WR_BYTE10,
		UART_ACK10,
		UART_WAIT10,
		WR_BYTE11,
		UART_ACK11,
		UART_WAIT11,
		WR_BYTE12,
		UART_ACK12,
		UART_WAIT12,
		WR_BYTE13,
		UART_ACK13,
		UART_WAIT13,
		WR_BYTE14,
		UART_ACK14,
		UART_WAIT14,
		WR_BYTE15,
		UART_ACK15,
		UART_WAIT15,
		WR_BYTE16,
		UART_ACK16,
		UART_WAIT16,
		WR_BYTE17,
		UART_ACK17,
		UART_WAIT17,
		WORD_DONE,
		DONE
		);
	
		signal ciph_curr_state : ciph_state_t;
		signal ciph_next_state : ciph_state_t;
	
		signal ciph_bsy_s : std_logic;
		signal ciph_bsy_r : std_logic;
	
		signal ciph_start_tx_s : std_logic;
		signal ciph_start_tx_r : std_logic;
	
		signal ciph_cntr_up_s : std_logic;
		signal ciph_cntr_up_r : std_logic;
	
		signal ciph_cntr_ld_s : std_logic;
		signal ciph_cntr_ld_r : std_logic;
	
		signal curr_ciph_r : std_logic_vector(aes_data_i'range);
		signal next_ciph_s : std_logic_vector(aes_data_i'range);
	
		signal ciph_word_s : std_logic_vector(word_o'range);
		signal ciph_word_r : std_logic_vector(word_o'range);
	
		-- TRACE FSM Signals ---
		signal trace_curr_state : trace_state_t;
		signal trace_next_state : trace_state_t;
	
		signal trace_bsy_s : std_logic;
		signal trace_bsy_r : std_logic;
	
		signal trace_start_tx_s : std_logic;
		signal trace_start_tx_r : std_logic;
	
		signal trace_cntr_up_s : std_logic;
		signal trace_cntr_up_r : std_logic;
	
		signal trace_cntr_ld_s : std_logic;
		signal trace_cntr_ld_r : std_logic;
	
		signal curr_sample_r : std_logic_vector(tr_data_i'range);
		signal next_sample_s : std_logic_vector(tr_data_i'range);
	
		signal trace_word_s : std_logic_vector(word_o'range);
		signal trace_word_r : std_logic_vector(word_o'range);
	
	
	begin
		ciph_is <= aes_data_i when ciph_vld_i = '1' else
		           ciph_ir;
	
		ciph_state_dec : process (start_enc_i, uart_bsy_i, counter_os, ciph_curr_state)
		begin
			ciph_next_state <= ciph_curr_state;
			case ciph_curr_state is
				when IDLE =>
	
					if (start_enc_i = '1') then
						ciph_next_state <= START_TRANS;
					else
						ciph_next_state <= IDLE;
					end if;
				when START_TRANS =>
	
					ciph_next_state <= WR_BYTE;
				when WR_BYTE =>
	
					ciph_next_state <= UART_ACK;
				when UART_ACK =>
	
					if (uart_bsy_i = '1') then
						ciph_next_state <= UART_WAIT;
					else
						ciph_next_state <= UART_ACK;
					end if;
				when UART_WAIT =>
	
					if (uart_bsy_i = '0') then
						ciph_next_state <= BYTE_DONE;
					else
						ciph_next_state <= UART_WAIT;
					end if;
				when BYTE_DONE =>
	
					if (counter_os = cipher_nbyte) then
						ciph_next_state <= DONE;
					else
						ciph_next_state <= WR_BYTE;
					end if;
				when DONE =>
	
					ciph_next_state <= IDLE;
				when others =>
	
					null;
			end case;
		end process;
	
		ciph_output_dec : process (ciph_curr_state)
		begin
			next_ciph_s <= curr_ciph_r;
			ciph_cntr_up_s <= '0';
			ciph_bsy_s <= ciph_bsy_r;
			ciph_start_tx_s <= '0';
			ciph_word_s <= ciph_word_r;
			ciph_cntr_ld_s <= '0';
			case ciph_curr_state is
				when IDLE =>
	
					ciph_bsy_s <= '0';
				when START_TRANS =>
	
					ciph_bsy_s <= '1';
					next_ciph_s <= ciph_ir;
					ciph_cntr_ld_s <= '1';
				when WR_BYTE =>
	
					ciph_word_s <= curr_ciph_r(word_o'range);
					ciph_cntr_up_s <= '1';
					next_ciph_s <= ZEROS & curr_ciph_r(curr_ciph_r'HIGH downto word_o'HIGH + 1);
					ciph_start_tx_s <= '1';
				when UART_ACK =>
	
					ciph_start_tx_s <= '1';
				when UART_WAIT =>
	
				when BYTE_DONE =>
	
				when DONE =>
	
				when others =>
	
					null;
			end case;
		end process;
	
		trce_state_dec : process (start_tr_i, uart_bsy_i, addr_os, trace_curr_state)
		begin
			trace_next_state <= trace_curr_state;
			case trace_curr_state is
				when IDLE =>
	
					if (start_tr_i = '1') then
						trace_next_state <= START_TRANS;
					else
						trace_next_state <= IDLE;
					end if;
				when START_TRANS =>
	
					trace_next_state <= WR_BYTE0;
				when WR_BYTE0 =>
	
					trace_next_state <= UART_ACK0;
				when UART_ACK0 =>
	
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT0;
					else
						trace_next_state <= UART_ACK0;
					end if;
				when UART_WAIT0 =>
	
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE1;
					else
						trace_next_state <= UART_WAIT0;
					end if;
				when WR_BYTE1 =>
	
					trace_next_state <= UART_ACK1;
				when UART_ACK1 =>
	
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT1;
					else
						trace_next_state <= UART_ACK1;
					end if;
				when UART_WAIT1 =>
	
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE2;
					else
						trace_next_state <= UART_WAIT1;
					end if;
	
				when WR_BYTE2 =>
					trace_next_state <= UART_ACK2;
				when UART_ACK2 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT2;
					else
						trace_next_state <= UART_ACK2;
					end if;
				when UART_WAIT2 =>
	
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE3;
					else
						trace_next_state <= UART_WAIT2;
					end if;
			  when WR_BYTE3 =>
					trace_next_state <= UART_ACK3;
				when UART_ACK3 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT3;
					else
						trace_next_state <= UART_ACK3;
					end if;
				when UART_WAIT3 =>
	
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE4;
					else
						trace_next_state <= UART_WAIT3;
					end if;
			   when WR_BYTE4 =>
					trace_next_state <= UART_ACK4;
				when UART_ACK4 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT4;
					else
						trace_next_state <= UART_ACK4;
					end if;
				when UART_WAIT4 =>
	
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE5;
					else
						trace_next_state <= UART_WAIT4;
					end if;
				when WR_BYTE5 =>
					trace_next_state <= UART_ACK5;
				when UART_ACK5 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT5;
					else
						trace_next_state <= UART_ACK5;
					end if;
				when UART_WAIT5 =>
	
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE6;
					else
						trace_next_state <= UART_WAIT5;
					end if;
				when WR_BYTE6 =>
					trace_next_state <= UART_ACK6;
				when UART_ACK6 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT6;
					else
						trace_next_state <= UART_ACK6;
					end if;
				when UART_WAIT6 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE7;
					else
						trace_next_state <= UART_WAIT6;
					end if;	
					
				when WR_BYTE7 =>
					trace_next_state <= UART_ACK7;
				when UART_ACK7 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT7;
					else
						trace_next_state <= UART_ACK7;
					end if;
				when UART_WAIT7 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE8;
					else
						trace_next_state <= UART_WAIT7;
					end if;		
					
					when WR_BYTE8 =>
					trace_next_state <= UART_ACK8;
				when UART_ACK8 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT8;
					else
						trace_next_state <= UART_ACK8;
					end if;
				when UART_WAIT8 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE9;
					else
						trace_next_state <= UART_WAIT8;
					end if;	
					
			   when WR_BYTE9 =>
					trace_next_state <= UART_ACK9;
				when UART_ACK9 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT9;
					else
						trace_next_state <= UART_ACK9;
					end if;
				when UART_WAIT9 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE10;
					else
						trace_next_state <= UART_WAIT9;
					end if;	
					
				when WR_BYTE10 =>
					trace_next_state <= UART_ACK10;
				when UART_ACK10 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT10;
					else
						trace_next_state <= UART_ACK10;
					end if;
				when UART_WAIT10 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE11;
					else
						trace_next_state <= UART_WAIT10;
					end if;		
					
				when WR_BYTE11 =>
					trace_next_state <= UART_ACK11;
				when UART_ACK11 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT11;
					else
						trace_next_state <= UART_ACK11;
					end if;
				when UART_WAIT11 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE12;
					else
						trace_next_state <= UART_WAIT11;
					end if;		
				when WR_BYTE12 =>
					trace_next_state <= UART_ACK12;
				when UART_ACK12 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT12;
					else
						trace_next_state <= UART_ACK12;
					end if;
				when UART_WAIT12 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE13;
					else
						trace_next_state <= UART_WAIT12;
					end if;	
			   when WR_BYTE13 =>
					trace_next_state <= UART_ACK13;
				when UART_ACK13 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT13;
					else
						trace_next_state <= UART_ACK13;
					end if;
				when UART_WAIT13 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE14;
					else
						trace_next_state <= UART_WAIT13;
					end if;	
				when WR_BYTE14 =>
					trace_next_state <= UART_ACK14;
				when UART_ACK14 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT14;
					else
						trace_next_state <= UART_ACK14;
					end if;
				when UART_WAIT14 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE15;
					else
						trace_next_state <= UART_WAIT14;
					end if;	
			   when WR_BYTE15 =>
					trace_next_state <= UART_ACK15;
				when UART_ACK15 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT15;
					else
						trace_next_state <= UART_ACK15;
					end if;
				when UART_WAIT15 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE16;
					else
						trace_next_state <= UART_WAIT15;
					end if;	
					
				 when WR_BYTE16 =>
					trace_next_state <= UART_ACK16;
				when UART_ACK16 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT16;
					else
						trace_next_state <= UART_ACK16;
					end if;
				when UART_WAIT16 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WR_BYTE17;
					else
						trace_next_state <= UART_WAIT16;
					end if;		
				when WR_BYTE17 =>
					trace_next_state <= UART_ACK17;
				when UART_ACK17 =>
					if (uart_bsy_i = '1') then
						trace_next_state <= UART_WAIT17;
					else
						trace_next_state <= UART_ACK17;
					end if;
				when UART_WAIT17 =>
					if (uart_bsy_i = '0') then
						trace_next_state <= WORD_DONE;
					else
						trace_next_state <= UART_WAIT17;
					end if;
	
				when WORD_DONE =>
	
					if (addr_os = num_sample) then
						trace_next_state <= DONE;
					else
						trace_next_state <= WR_BYTE0;
					end if;
				when DONE =>
	
					trace_next_state <= IDLE;
				when others =>
	
					null;
			end case;
		end process;
	
	
		trce_output_dec : process (trace_curr_state)
		begin
			next_sample_s <= curr_sample_r;
			trace_cntr_up_s <= '0';
			trace_bsy_s <= trace_bsy_r;
			trace_start_tx_s <= '0';
			trace_word_s <= trace_word_r;
			trace_cntr_ld_s <= '0';
			case trace_curr_state is
				when IDLE =>
	
					trace_bsy_s <= '0';
				when START_TRANS =>
	
					next_sample_s <= tr_data_i;
					trace_cntr_ld_s <= '1';
					trace_bsy_s <= '1';
				when WR_BYTE0 =>
	
					trace_word_s <= curr_sample_r(143 downto 136);
					trace_start_tx_s <= '1';
					
				when UART_ACK0 =>
	
					trace_start_tx_s <= '1';
				when UART_WAIT0 =>
	
				when WR_BYTE1 =>
	
					trace_word_s <= curr_sample_r(135 downto 128);
					trace_start_tx_s <= '1';
					
				when UART_ACK1 =>
	
					trace_start_tx_s <= '1';
				when UART_WAIT1 =>
				when WR_BYTE2 =>
					trace_word_s <= curr_sample_r(127 downto 120);
					trace_start_tx_s <= '1';
	
				when UART_ACK2 =>
	
					trace_start_tx_s <= '1';
				when UART_WAIT2 =>
	
	            when WR_BYTE3 =>
					trace_word_s <= curr_sample_r(119 downto 112);
					trace_start_tx_s <= '1';
					
				when UART_ACK3 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT3 =>
				
				 when WR_BYTE4 =>
					trace_word_s <= curr_sample_r(111 downto 104);
					trace_start_tx_s <= '1';
					
				when UART_ACK4 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT4 =>
				
	             when WR_BYTE5 =>
					trace_word_s <= curr_sample_r(103 downto 96);
					trace_start_tx_s <= '1';

				when UART_ACK5 =>
					trace_start_tx_s <= '1';
				when UART_WAIT5 =>
	             when WR_BYTE6 =>
					trace_word_s <= curr_sample_r(95 downto 88);
					trace_start_tx_s <= '1';
					
				when UART_ACK6 =>
					trace_start_tx_s <= '1';
				when UART_WAIT6 =>
				
				when WR_BYTE7 =>
					trace_word_s <= curr_sample_r(87 downto 80);
					trace_start_tx_s <= '1';
					
				when UART_ACK7 =>
					trace_start_tx_s <= '1';
				when UART_WAIT7 =>
				when WR_BYTE8 =>
					trace_word_s <= curr_sample_r(79 downto 72);
					trace_start_tx_s <= '1';
					
				when UART_ACK8 =>
					trace_start_tx_s <= '1';
				when UART_WAIT8 =>
				when WR_BYTE9 =>
					trace_word_s <= curr_sample_r(71 downto 64);
					trace_start_tx_s <= '1';
					
				when UART_ACK9 =>
					trace_start_tx_s <= '1';
				when UART_WAIT9 =>
				when WR_BYTE10 =>
					trace_word_s <= curr_sample_r(63 downto 56);
					trace_start_tx_s <= '1';
					
				when UART_ACK10 =>
					trace_start_tx_s <= '1';
				when UART_WAIT10 =>
				when WR_BYTE11 =>
					trace_word_s <= curr_sample_r(55 downto 48);
					trace_start_tx_s <= '1';

				when UART_ACK11 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT11 =>
				
				when WR_BYTE12 =>
					trace_word_s <= curr_sample_r(47 downto 40);
					trace_start_tx_s <= '1';
				
				when UART_ACK12 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT12 =>
				
				when WR_BYTE13 =>
					trace_word_s <= curr_sample_r(39 downto 32);
					trace_start_tx_s <= '1';
					
				when UART_ACK13 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT13 =>
				
				when WR_BYTE14 =>
					trace_word_s <= curr_sample_r(31 downto 24);
					trace_start_tx_s <= '1';
					
				when UART_ACK14 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT14 =>
				
				when WR_BYTE15 =>
					trace_word_s <= curr_sample_r(23 downto 16);
					trace_start_tx_s <= '1';
					
				when UART_ACK15 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT15 =>
				
				when WR_BYTE16 =>
					trace_word_s <= curr_sample_r(15 downto 8);
					trace_start_tx_s <= '1';
					
				when UART_ACK16 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT16 =>
				
				when WR_BYTE17 =>
					trace_word_s <= curr_sample_r(7 downto 0);
					trace_start_tx_s <= '1';
					trace_cntr_up_s <= '1';
					
				when UART_ACK17 =>
					trace_start_tx_s <= '1';
					
				when UART_WAIT17 =>
	
				when WORD_DONE =>
					next_sample_s <= tr_data_i;
					
				when DONE =>
	
				when others =>
	
					null;
			end case;
		end process;
	
	
		reg_update : process (clk_i, n_reset_i)
		begin
			if (rising_edge(clk_i)) then
				if (n_reset_i = '0') then
					ciph_curr_state <= IDLE;
					curr_ciph_r <= (others => '0');
					ciph_cntr_up_r <= '0';
					ciph_bsy_r <= '0';
					ciph_start_tx_r <= '0';
					ciph_word_r <= (others => '0');
					ciph_cntr_ld_r <= '0';
	
					trace_curr_state <= IDLE;
					curr_sample_r <= (others => '0');
					trace_cntr_up_r <= '0';
					trace_bsy_r <= '0';
					trace_start_tx_r <= '0';
					trace_word_r <= (others => '0');
					trace_cntr_ld_r <= '0';
					ciph_ir <= (others => '0');
				else
					ciph_curr_state <= ciph_next_state;
					curr_ciph_r <= next_ciph_s;
					ciph_cntr_up_r <= ciph_cntr_up_s;
					ciph_bsy_r <= ciph_bsy_s;
					ciph_start_tx_r <= ciph_start_tx_s;
					ciph_word_r <= ciph_word_s;
					ciph_cntr_ld_r <= ciph_cntr_ld_s;
	
					trace_curr_state <= trace_next_state;
					curr_sample_r <= next_sample_s;
					trace_cntr_up_r <= trace_cntr_up_s;
					trace_bsy_r <= trace_bsy_s;
					trace_start_tx_r <= trace_start_tx_s;
					trace_word_r <= trace_word_s;
					trace_cntr_ld_r <= trace_cntr_ld_s;
					ciph_ir <= ciph_is;
	
				end if;
			end if;
		end process;
	
	
	
		cntr : counter_up
			generic map(SIZE => 5)
			port map(
				n_reset_i => n_reset_i,
				clk_i => clk_i,
				load_i => ciph_cntr_ld_r,
				up_i => ciph_cntr_up_r,
				val_i => (others => '0'),
				val_o => counter_os
			);
	
				tr_cntr : counter_up
				port map(
					n_reset_i => n_reset_i,
					clk_i => clk_i,
					load_i => trace_cntr_ld_r,
					up_i => trace_cntr_up_r,
					val_i => (others => '0'),
					val_o => addr_os
			);
	
			busy_o <= trace_bsy_r or ciph_bsy_r;
	
			word_o <= ciph_word_r when ciph_bsy_r = '1' else
			          trace_word_r when trace_bsy_r = '1' else
			          (others => '0');
	
			word_vld_o <= ciph_start_tx_r when ciph_bsy_r = '1' else
			              trace_start_tx_r when trace_bsy_r = '1' else
			              '0';
	
			addr_o <= addr_os;
	
	end behave;