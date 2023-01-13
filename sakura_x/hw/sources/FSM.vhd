-- RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
-- Copyright 2023, School of Computer and Communication Sciences, EPFL.
--
-- All rights reserved. Use of this source code is governed by a
-- BSD-style license that can be found in the LICENSE.md file.

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FSM is
  Port (
    -- BLK KEY INTERFACE
    blk_kin     : in  std_logic_vector(127 downto 0); 
    blk_krdy    : in  std_logic;
    blk_kvld    : out std_logic;
    -- BLK DATA INTERFACE
    blk_din     : in  std_logic_vector(127 downto 0);  
    blk_drdy    : in  std_logic; 
    blk_dout    : out std_logic_vector(127 downto 0);  
    blk_dvld    : out std_logic; 

    -- AES KEY INTERFACE 
    aes_kin     : out std_logic_vector(127 downto 0); 
    aes_krdy    : out std_logic;
    aes_kvld    : in  std_logic;
    -- AES DATA INTERFACE
    aes_din     : out std_logic_vector(127 downto 0);  
    aes_drdy    : out std_logic; 
    aes_busy    : in  std_logic; 
    aes_dout    : in  std_logic_vector(127 downto 0);  
    aes_dvld    : in  std_logic; 

    -- SENSOR FIFO INTERFACE
    sens_trig   : out std_logic;
    sens_dout   : in  std_logic_vector(127 downto 0);
    sens_drdy   : out std_logic;
    sens_dvld   : in  std_logic;

    -- SENSOR CALIBRATION INTERFACE
    IDC_IDF   : out std_logic_vector(127 downto 0);
    IDC_IDF_en  : out std_logic;

    rst_n       : in std_logic;
    clk_i         : in std_logic
  );
       
end FSM;

architecture FSM_arch of FSM is

  type states is (IDLE,
                  GET_CMD, 
                  -- Manual calibration
                  GET_CALIBRATION, --wait for calib data
                  CALIBRATE, --set calib values to sensor
                  SENS_TRIGGER,
                  -- Set key
                  WAIT_KEY, 
                  SET_KEY, --set aes key
                  SET_KVLD,
                  -- Encrypt
                  WAIT_DATA,
                  SET_PT, --set aes plaintext
                  START_ENC,--start encryption and also start sensor recording
                  WAIT_ENC_DONE, --wait until the encryption is done
                  SET_CT, --save the ciphertext
                  -- Read sensor traces
                  WAIT_SENS_READ, --read sensor traces
                  DECODE_SENS_CMD, --check if there is more to read
                  READ_SENS_FIFO, --read from the sensor fifo
                  WAIT_SENS_VALID, 
                  WRITE_SENS_REG,
                  SET_SENS_DOUT,
                  SET_SENS_END --end reading from the sensor fifo
                  );

  signal state_next, state_reg : states;
  
  signal sensor_fifo_read, aes_drdy_s : std_logic;
  signal sens_trig_s, sens_trig_mux : std_logic;
  signal dout_mux : std_logic_vector(1 downto 0);
  signal sens_dout_q : std_logic_vector(127 downto 0);

begin


  blk_dout <= sens_dout_q when dout_mux = "01" else
              aes_dout;
              
  sens_trig <= sens_trig_s when sens_trig_mux = '1' else aes_drdy_s;
  aes_drdy <= aes_drdy_s;
  aes_kin <= blk_kin;
  aes_din <= blk_din;

idc_idf_proc: process(clk_i) is
begin
    if(clk_i'event and clk_i='1') then
    IDC_IDF <= blk_kin; --calibration received via key input
    end if;
  end process;


  -- Sensor data register
  sens_reg: process(clk_i) is
  begin
    if(clk_i'event and clk_i='1') then
      if(rst_n = '0') then
        sens_dout_q <= (others => '0');
      elsif (sensor_fifo_read = '1') then
        sens_dout_q <= sens_dout; 
      end if;
    end if;
  end process;

  -- State register
  state_proc: process(clk_i) is
  begin
    if(clk_i'event and clk_i='1') then
      if(rst_n = '0') then
        state_reg <= IDLE;
      else
        state_reg <= state_next;
      end if;
    end if;
  end process;

  -- Next state logic
  next_state: process(state_reg, blk_kin, blk_krdy, blk_din, blk_drdy, aes_dvld, sens_dvld) is
  begin
    case state_reg is
      when IDLE => 
        if(blk_krdy = '1') then
          state_next <= GET_CMD;
        else
          state_next <= IDLE;
        end if;
      when GET_CMD => 
        -- If command is calibrate manually 
        if(blk_kin(7 downto 0) = X"01") then
          state_next <= GET_CALIBRATION;
        -- If command is set key 
        elsif(blk_kin(7 downto 0) = X"04") then
          state_next <= WAIT_KEY;
        -- If command is encrypt 
        elsif(blk_kin(7 downto 0) = X"08") then
          state_next <= WAIT_DATA;
        -- If command is read sensor 
        elsif(blk_kin(7 downto 0) = X"10") then
          state_next <= WAIT_SENS_READ;
        else
          state_next <= GET_CMD;
        end if;
      -- Manual calibration
      -- wait for calibration data
      when GET_CALIBRATION => 
        if(blk_krdy = '1') then
          state_next <= CALIBRATE;
        else
          state_next <= GET_CALIBRATION;
        end if;
      -- set calibration values to sensor
      when CALIBRATE => 
        state_next <= SENS_TRIGGER;
      when SENS_TRIGGER => 
        state_next <= IDLE;
      -- Set key
      when WAIT_KEY => 
        if(blk_krdy = '1') then
          state_next <= SET_KEY;
        else
          state_next <= WAIT_KEY;
        end if;
      when SET_KEY => 
        state_next <= SET_KVLD;
      when SET_KVLD => 
        state_next <= IDLE;  
      -- Encrypt
      when WAIT_DATA => 
        if(blk_drdy = '1') then
          state_next <= SET_PT;
        else
          state_next <= WAIT_DATA;
        end if;
      when SET_PT => 
        state_next <= START_ENC;
      when START_ENC => 
        state_next <= WAIT_ENC_DONE;
      when WAIT_ENC_DONE => 
        if(aes_dvld = '1') then
          state_next <= SET_CT;
        else
          state_next <= WAIT_ENC_DONE;
        end if;
      when SET_CT => 
        state_next <= IDLE;
      -- Read sensor traces
      when WAIT_SENS_READ => 
        if(blk_drdy = '1') then
          state_next <= DECODE_SENS_CMD;
        else
          state_next <= WAIT_SENS_READ;
        end if;
      when DECODE_SENS_CMD => 
        -- If command is read sensor sample
        if(blk_din(7 downto 0) = X"01") then
          state_next <= READ_SENS_FIFO;
        -- If command is end sensor read 
        elsif(blk_din(7 downto 0) = X"02") then
          state_next <= SET_SENS_END;
        else
          state_next <= IDLE;
        end if;
      when READ_SENS_FIFO => 
        state_next <= WAIT_SENS_VALID;
      when WAIT_SENS_VALID => 
        if(sens_dvld = '1') then
          state_next <= WRITE_SENS_REG;
        else
          state_next <= WAIT_SENS_VALID;
        end if;
      when WRITE_SENS_REG => 
        state_next <= SET_SENS_DOUT;
      when SET_SENS_DOUT => 
        state_next <= WAIT_SENS_READ;
      when SET_SENS_END => 
        state_next <= IDLE;
    end case;
  end process;

  -- Output logic
  output_logic: process(state_reg) is
  begin
    blk_kvld      <= '0';
    blk_dvld      <= '0';
    aes_krdy      <= '0';
    aes_drdy_s    <= '0';
    IDC_IDF_en    <= '0';
    sens_trig_s   <= '0';
    sens_trig_mux <= '0';
    sensor_fifo_read   <= '0';
    sens_drdy     <= '0';
    dout_mux      <= "00";

    case state_reg is
      when IDLE => 
      when GET_CMD =>
        blk_kvld      <= '1'; 
      when GET_CALIBRATION => 
      when CALIBRATE => 
        IDC_IDF_en    <= '1';
        blk_kvld      <= '1';
      when SENS_TRIGGER => 
        sens_trig_s   <= '1';
        sens_trig_mux <= '1';
      when WAIT_KEY => 
      when SET_KEY => 
        aes_krdy      <= '1';
      when SET_KVLD => 
        blk_kvld      <= '1';
      when WAIT_DATA => 
      when SET_PT => 
      when START_ENC => 
        aes_drdy_s    <= '1';
      when WAIT_ENC_DONE => 
        dout_mux      <= "00";
      when SET_CT => 
        dout_mux      <= "00";
        blk_dvld      <= '1';
      when WAIT_SENS_READ => 
        dout_mux      <= "01";
      when DECODE_SENS_CMD => 
        dout_mux      <= "01";
      when READ_SENS_FIFO => 
        dout_mux      <= "01";
        sens_drdy     <= '1';
      when WAIT_SENS_VALID => 
        dout_mux      <= "01";
      when WRITE_SENS_REG => 
        dout_mux      <= "01";
        sensor_fifo_read<= '1';
      when SET_SENS_DOUT => 
        dout_mux      <= "01";
        blk_dvld      <= '1';
      when SET_SENS_END =>
        blk_dvld      <= '1'; 
    end case;
  end process;

end FSM_arch;


