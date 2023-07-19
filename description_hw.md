# Alveo
<details>
<summary>AES_SCA_kernel.vhd</summary>

```
    AES_SCA_kernel.vhd is the top module of this project. 
```

</details>

<details>
<summary>AxiFlusher.sv</summary>

```
   The AxiFlusher.sv reads the traces from BRAM and uses the Advanced eXtensible Interface (AXI) to send the traces to the shell. 
```

</details>

<details>
<summary>AxiLiteFSM.vhd</summary>

```
   AxiLiteFSM.vhd implements a Finite State Machine (FSM) that orchestrates the calibration of the voltage-drop sensor, the recording of the traces, the reading of the traces from the fifo, and the trigger of the AES encryption.
```

</details>

<details>
<summary>BramDumper.vhd</summary>

```
   Writes the sensor traces to the BRAM.
```
</details>

<details>
<summary>counter_simple.vhd</summary>

```
   A simple counter implementation that is used in various parts of the project. 
```

</details>

<details>
<summary>cross_clk_sync.vhd</summary>

```
   Cross-clock synchronization circuit, used to cross a pulse from one clock domain to another.
```

</details>

<details>
<summary>design_package.vhd</summary>

```
   VHDL package containing useful functions (log, etc.)
```
</details>

<details>
<summary>URAMLike.v</summary>

```
   Instantiation of the URAM component for vitis. 
```

</details>

<details>
<summary>AES_Comp.v</summary>

```
module AES_Comp(Kin, Din, Dout, Krdy, Drdy, RSTn, EN, CLK, BSY, Kvld, Dvld);

    Module that performs the Advanced Encryption Standard (AES) with a key length of 128 bits (AES-128). Consequently, the module takes the key (Kin) and the plaintext (Din) as input, and outputs the ciphertext (Dout).

    input  [127:0] Kin:  AES Key
    input  [127:0] Din:  Data (plaintext) input
    output [127:0] Dout: Data (ciphertext) output
    input  Krdy:         Key input ready
    input  Drdy:         Data input ready
    input  RSTn:         Reset (Low active)
    input  EN:           AES circuit enable
    input  CLK:          System clock
    output BSY:          Busy signal
    output Kvld:         Key output valid
    output Dvld:         Data output valid
```
</details>

<details>
<summary>sensor_top_multiple.vhd</summary>

```
   sensor_top_multiple.vhd is the top file of sensor_top.vhd which implements one or more voltage-drop sensors. 

    N_SENSORS:      the number of sensors that will be implemented
    SENS_SET_BASE:  id of the sensor
    COARSE_WIDTH:   number of LUT/LD elements preceding the sensor 
    FINE_WIDTH:     number of CARRY4 elements preceding the sensor
    SENSOR_WIDTH:   length of the sensor output

    input  clk_in:          clock that propagates through
    output dlay_line_o:     output of the sensor
    input  sens_calib_clk:  clock for calibration signals
    input  sens_calib_val:  values for calibration (IDC/IDF)
    input  sens_calib_trg:  trigger signal for calibration values
    input  sens_calib_id:   id for each sensor
```
</details>

<details>
<summary>sensor_top.vhd</summary>

```
   sensor_top.vhd is the top file of sensor.vhd and instantiates one voltage-drop sensor. 

    N_SENSORS:      the number of sensors that will be implemented
    SENS_SET_BASE:  id of the sensor
    COARSE_WIDTH:   number of LUT/LD elements preceding the sensor 
    FINE_WIDTH:     number of CARRY4 elements preceding the sensor
    SENSOR_WIDTH:   length of the sensor output

    input  sampling_clk_i   clock for the FDs
    input  clk_i            clock that propagates through the elements
    input  ID_coarse_i      specifies the number of LUTs/LD elements preceding the sensor
    input  ID_fine_i        specifies the number of CARRY4 elements preceding the sensor
    output sensor_o         output of the sensor
```
</details>

<details>
<summary>sensor_RDS.vhd</summary>

```
   sensor_RDS.vhd implements the newly designed routing delay sensor (RDS).

    COARSE_WIDTH:   number of LUT/LD elements preceding the sensor
    FINE_WIDTH:     number of CARRY4 elements preceding the sensor     
    SENSOR_WIDTH:   number of FDs used for the measurements
    SET_NUMBER:     unique number per sensor. If there is only one sensor, SET_NUMBER is fixed to 1. 

    input  clk_i:           clock that propagates through the elements
    input  sampling_clk_i:  clock for the FDs
    input  ID_coarse_i:     specifies the number of LUTs/LD elements preceding the sensor
    input  ID_fine_i:       specifies the number of CARRY4 elements preceding the sensor
    output sensor_o:        output of the sensor
```
</details>

<details>
<summary>sensor_TDC.vhd</summary>

```
   sensor_TDC.vhd implements the traditional Time-to-Digital-Converter (TDC). 

    COARSE_WIDTH:   number of LUT/LD elements preceding the sensor
    FINE_WIDTH:     number of CARRY4 elements preceding the sensor     
    SENSOR_WIDTH:   number of FDs used for the measurements
    SET_NUMBER:     unique number per sensor. If there is only one sensor, SET_NUMBER is fixed to 1. 

    input  clk_i:           clock that propagates through the elements
    input  sampling_clk_i:  clock for the FDs
    input  ID_coarse_i:     specifies the number of LUTs/LD elements preceding the sensor
    input  ID_fine_i:       specifies the number of CARRY4 elements preceding the sensor. Currently unused.
    output sensor_o:        output of the sensor
```
</details>

<details>
<summary>sensor_sim.vhd</summary>

```
Sensor replacement used for simulation. Reads random values from an array.
```
</details>


# Basys

<details>
<summary>system_top_artix7_fifo_aes.vhd</summary>

```
system_top_artix7_fifo_aes.vhd is the top module of this project.
```

</details>

<details>
<summary>AES_Comp.v</summary>

```
module AES_Comp(Kin, Din, Dout, Krdy, Drdy, EncDec, RSTn, EN, CLK, BSY, Kvld, Dvld);

    Module that performs the Advanced Encryption Standard (AES) with a key length of 128 bits (AES-128). Consequently, the module takes the key (Kin) and the plaintext (Din) as input, and outputs the ciphertext (Dout).

    input  [127:0] Kin:  AES Key
    input  [127:0] Din:  Data (plaintext) input
    output [127:0] Dout: Data (ciphertext) output
    input  Krdy:         Key input ready
    input  Drdy:         Data input ready
    input  EncDec:       0:Encryption 1:Decryption
    input  RSTn:         Reset (Low active)
    input  EN:           AES circuit enable
    input  CLK:          System clock
    output BSY:          Busy signal
    output Kvld:         Key output valid
    output Dvld:         Data output valid
```

</details>

<details>
<summary>io_wrapper.vhd</summary>

```
   Main controller of the system. Receives commands from the host through the UART interface, and sends data back to the host. It controls the AES (plaintext, key, and ciphertext), collects, stores, and offloads the sensor traces to the host.
   
   It instantiates the following modules to achieve its functionality:
   * BRAM_dual_clock.vhd, describes the BRAM memory in which the sensor measurements are stored by the io_wrapper.vhd.
   * FSM_FIFO.vhd, reads the sensor measurements from the BRAM.
   * read_traces.vhd, reads traces from the BRAM to send them to the host
   * counter_up.vhd, implements a simple counter that is used in various parts of the project.
   * address_dec.vhd, implements an address decoder to decode commands from the host
   * config_registers.vhd, implements memory mapped configuration registers, to which the host can write
   * data_dec.vhd, decodes UART data
   * data_enc.vhd, encodes UART data
   * io_controller_fifo_aes.vhd, implements a FIFO between the AES and the io_wrapper
   * io_fsm_fifo_aes.vhd, implements the FSM of the IO wrapper
   * UART.vhd, implementing the UART communication between the io_wrapper and the host machine using rxuartlite.v and txuartlite.v
```

</details>

<details>
<summary>reset_wrapper.vhd</summary>

```
   Reset system generator. Generates reset signals for AES, sensor, and the system based on external resets controlled by the host PC.
```

</details>

<details>
<summary>sig_delay.vhd</summary>

```
   Delays input signal by 15 clock cycles.
```

</details>

<details>
<summary>xadc.vhd</summary>

```
   xadc.vhd implements an on-chip temperature sensor.
```

</details>

<details>

<summary>sensor_top.vhd</summary>

```
   sensor_top.vhd is the top file of sensor.vhd and implements the routing delay sensor (RDS). 
```

</details>

<details>

<summary>sensor.vhd</summary>

```
   sensor.vhd implements the routing delay sensor (RDS).

   COARSE_WIDTH:   number of LUT/LD elements preceding the sensor 
   FINE_WIDTH:     number of CARRY4 elements preceding the sensor
   SENSOR_WIDTH:   length of the sensor output
   SET_NUMBER:     unique number per sensor, if there is only one sensor, SET_NUMBER is fixed to 1

   input  clk_i:          clock that propagates through
   input sampling_clk_i:  clock for the FDs
   input ID_coarse_i:     specifies the number of LUTs/LD elements preceding the sensor
   input ID_fine_i:       specifies the number of CARRY4 elements preceding the sensor  
   output sensor_o:       output of the sensor    
```

</details>



<details>

<summary>design_package.vhd</summary>

```
   VHDL package containing useful functions (log, etc.)
```

</details>


# Sakura-X
<details>

<summary>chip_sasebo_giii_aes.v</summary>

```
   HRDS/chip_sasebo_giii_aes.v is the top module of the project that implements HRDS.
   RDS/chip_sasebo_giii_aes.v is the top module of the project that implements RDS.
   TDC/chip_sasebo_giii_aes.v is the top module of the project that implements TDC.
   VRDS/chip_sasebo_giii_aes.v is the top module of the project that implements VRDS.
```

</details>

<details>
<summary>AES_Comp.v</summary>

```
module AES_Comp(Kin, Din, Dout, Krdy, Drdy, EncDec, RSTn, EN, CLK, BSY, Kvld, Dvld);

    Module that performs the Advanced Encryption Standard (AES) with a key length of 128 bits (AES-128). Consequently, the module takes the key (Kin) and the plaintext (Din) as input, and outputs the ciphertext (Dout).

    input  [127:0] Kin:  AES Key
    input  [127:0] Din:  Data (plaintext) input
    output [127:0] Dout: Data (ciphertext) output
    input  Krdy:         Key input ready
    input  Drdy:         Data input ready
    input  EncDec:       0:Encryption 1:Decryption
    input  RSTn:         Reset (Low active)
    input  EN:           AES circuit enable
    input  CLK:          System clock
    output BSY:          Busy signal
    output Kvld:         Key output valid
    output Dvld:         Data output valid
```

</details>

<details>

<summary>FSM.vhd</summary>

```
   FSM.vhd implements a Finite State Machine (FSM) that orchestrates the read/write operations to and from the software, triggers the AES encryption as well as the calibration of the voltage-drop sensor. 
```

</details>

<details>

<summary>sensor_fifo.vhd</summary>

```
   sensor_fifo.vhd implements a fifo to store the measurements of the sensor before sending them to the software.

   N_SAMPLES:     number of samples per trace

   input sens_fifo_din:          data (sensor measurement) for the input of the fifo
   input sens_fifo_trig:         trigger signal to write to the fifo
   input sens_fifo_drdy:         ready signal for the read side of the fifo
   output sens_fifo_dout:        data (sensor measurements) to be read from the fifo
   output sens_fifo_dvld:        valid signal for the read side of the fifo
   input clk_wr:                 clock for the write side of the fifo
   input clk_rd:                 clock for the read side of the fifo
   input reset_wr_n:             reset for the write side of the fifo
   input reset_rd_n:             reset for the read side of the fifo
```
   
</details>

<details>

<summary>sensor_wrapper_top.vhd</summary>

```
   sensor_wrapper_top.vhd implements a voltage-drop sensor. 

    COARSE_WIDTH:   number of LUT/LD elements preceding the sensor 
    FINE_WIDTH:     number of CARRY4 elements preceding the sensor
    SENSOR_WIDTH:   length of the sensor output

    input  clk_i:          clock that propagates through
    input IDC_IDF_en_i:    enable signal for ID_coarse_i and ID_fine_i
    output sensor_o:       output of the sensor    
    input ID_coarse_i:     specifies the number of LUTs/LD elements preceding the sensor
    input ID_fine_i:       specifies the number of CARRY4 elements preceding the sensor    
```

</details>

<details>

<summary>sensor_top.vhd</summary>

```
   sensor_top.vhd is the top file of sensor.vhd and implements a voltage-drop sensor. 

   COARSE_WIDTH:   number of LUT/LD elements preceding the sensor 
   FINE_WIDTH:     number of CARRY4 elements preceding the sensor
   SENSOR_WIDTH:   length of the sensor output
   SET_NUMBER:     unique number per sensor, if there is only one sensor, SET_NUMBER is fixed to 1

   input  clk_i:          clock that propagates through
   input sampling_clk_i:  clock for the FDs
   input ID_coarse_i:     specifies the number of LUTs/LD elements preceding the sensor
   input ID_fine_i:       specifies the number of CARRY4 elements preceding the sensor  
   output sensor_o:       output of the sensor    
```

</details>

<details>

<summary>sensor.vhd</summary>

```
   HRDS/sensor.vhd implements the horizontal routing delay sensor.
   RDS/sensor.vhd implements the routing delay sensor.
   TDC/sensor.vhd implements the traditional Time-to-Digital-Converter (TDC) sensor.
   VRDS/sensor.vhd implements the vertical routing delay sensor. 

   COARSE_WIDTH:   number of LUT/LD elements preceding the sensor 
   FINE_WIDTH:     number of CARRY4 elements preceding the sensor
   SENSOR_WIDTH:   length of the sensor output
   SET_NUMBER:     unique number per sensor, if there is only one sensor, SET_NUMBER is fixed to 1

   input  clk_i:          clock that propagates through
   input sampling_clk_i:  clock for the FDs
   input ID_coarse_i:     specifies the number of LUTs/LD elements preceding the sensor
   input ID_fine_i:       specifies the number of CARRY4 elements preceding the sensor  
   output sensor_o:       output of the sensor    
```

</details>

<details>
<summary>reset_gen.vhd</summary>

```
   reset_gen.vhd implements a reset generator.
```

</details>

<details>
<summary>counter_small.vhd</summary>
   
```
   counter_small.vhd implements a simple counter that is used in various parts of the project.
```

</details>


<details>
<summary>lbus_if.v</summary>

```
   lbus_if.v implements the interface to the software to receive and send data.
```

</details>