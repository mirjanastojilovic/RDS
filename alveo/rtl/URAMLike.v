/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

module URAMLike #(
  parameter DATA_WIDTH = 64,
  parameter ADDR_WIDTH = 12
)(
    input  clka,
    input  ena,
    input  [DATA_WIDTH/8-1:0] wea,
    input  [ADDR_WIDTH-1  :0] addra,
    input  [DATA_WIDTH-1  :0] dina,
 
    input  clkb,
    input  enb,
    input  [ADDR_WIDTH-1  :0] addrb,
    output [DATA_WIDTH-1  :0] doutb
);
  xpm_memory_sdpram #(
    .MEMORY_SIZE((1 << ADDR_WIDTH) * DATA_WIDTH),
    .MEMORY_PRIMITIVE("auto"),      
    .CLOCKING_MODE("common_clock"), 
    .MEMORY_INIT_FILE("none"),      
    .MEMORY_INIT_PARAM("0"),        
    .USE_MEM_INIT(1),               
    .WAKEUP_TIME("disable_sleep"),  
    .MESSAGE_CONTROL(0),            
    .ECC_MODE("no_ecc"),            
    .AUTO_SLEEP_TIME(0),            
    .WRITE_DATA_WIDTH_A(DATA_WIDTH),
    .BYTE_WRITE_WIDTH_A(8),         
    .ADDR_WIDTH_A(ADDR_WIDTH),      
    .READ_DATA_WIDTH_B(DATA_WIDTH), 
    .ADDR_WIDTH_B(ADDR_WIDTH),      
    .READ_RESET_VALUE_B("0"),       
    .READ_LATENCY_B(2),             
    .WRITE_MODE_B("read_first")
  )
  uram_inst (
    // Common module ports
    .sleep (1'b0),
    // Port A module ports
    .clka           (clka),
    .ena            (ena),
    .wea            (wea),
    .addra          (addra),
    .dina           (dina),
    .injectsbiterra (1'b0),
    .injectdbiterra (1'b0),
    // Port B module ports
    .clkb           (clkb),
    .rstb           (1'b0),
    .enb            (enb),
    .regceb         (1'b1),
    .addrb          (addrb),
    .doutb          (doutb),
    .sbiterrb       (),
    .dbiterrb       ()
  );

endmodule
