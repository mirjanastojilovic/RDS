/*-------------------------------------------------------------------------
 AES cryptographic module for FPGA on SASEBO-GIII
 
 File name   : chip_sasebo_giii_aes.v
 Version     : 1.0
 Created     : APR/02/2012
 Last update : APR/25/2013
 Desgined by : Toshihiro Katashita
 
 
 Copyright (C) 2012,2013 AIST
 
 By using this code, you agree to the following terms and conditions.
 
 This code is copyrighted by AIST ("us").
 
 Permission is hereby granted to copy, reproduce, redistribute or
 otherwise use this code as long as: there is no monetary profit gained
 specifically from the use or reproduction of this code, it is not sold,
 rented, traded or otherwise marketed, and this copyright notice is
 included prominently in any copy made.
 
 We shall not be liable for any damages, including without limitation
 direct, indirect, incidental, special or consequential damages arising
 from the use of this code.
 
 When you publish any results arising from the use of this code, we will
 appreciate it if you can cite our paper.
 (http://www.risec.aist.go.jp/project/sasebo/)
 -------------------------------------------------------------------------*/

/*-------------------------------------------------------------------------
Please note that this file is different from the file provided by the authors
named above. Several components have been added, removed or modified in order
to meet the requirements of this design. Therefore, this file is an adaptation
of the original file.
 -------------------------------------------------------------------------*/ 


//================================================ CHIP_SASEBO_GIII_AES
module CHIP_SASEBO_GIII_AES
  (// Local bus for GII
   lbus_di_a, lbus_do, lbus_wrn, lbus_rdn,
   lbus_clkn, lbus_rstn,

   // GPIO and LED
   gpio_startn, gpio_endn, gpio_exec, led,

   // Clock OSC
   osc_en_b);
   
   //------------------------------------------------
   // Local bus for GII
   input [15:0]  lbus_di_a;
   output [15:0] lbus_do;
   input         lbus_wrn, lbus_rdn;
   input         lbus_clkn, lbus_rstn;

   // GPIO and LED
   output        gpio_startn, gpio_endn, gpio_exec;
   output [9:0]  led;

   // Clock OSC
   output        osc_en_b;

   //------------------------------------------------
   // Internal clock
   wire         clk, rst;

   // Local bus
   reg [15:0]   lbus_a, lbus_di;
   
   // Block cipher
   (* DONT_TOUCH = "TRUE" *)
   wire [127:0] blk_kin, blk_din, blk_dout;
   (* DONT_TOUCH = "TRUE" *)
   wire         blk_krdy, blk_kvld, blk_drdy, blk_dvld;
   (* DONT_TOUCH = "TRUE" *)
   wire         blk_encdec, blk_en, blk_rstn, blk_busy;


   //------------------------------------------------
   assign led[0] = rst;
   assign led[1] = lbus_rstn;
   assign led[2] = 1'b0;
   assign led[3] = blk_rstn;
   assign led[4] = blk_encdec;
   assign led[5] = blk_krdy;
   assign led[6] = blk_kvld;
   assign led[7] = 1'b0;
   assign led[8] = blk_dvld;
   assign led[9] = blk_busy;
   assign osc_en_b = 1'b0;


   //------------------------------------------------added signals 
   //AES
   wire [127:0] aes_kin, aes_din, aes_dout;
   wire         aes_krdy, aes_kvld, aes_drdy, aes_dvld;
   wire         aes_encdec, aes_en, aes_rstn, aes_busy;
   wire         aes_clk;

   // Other connections
   wire [127:0] sensor_output, sens_fifo_dout, IDC_IDF;
   wire calib_done, calib_done_sync, IDC_IDF_en;
   wire sens_trig;
   wire sens_fifo_drdy, sens_fifo_dvld;
   wire sensor_clk, locked;
   wire rst_system_n, rst_sensor_n, rst_system_p, rst_sensor_p;



   //------------------------------------------------
   always @(posedge clk) if (lbus_wrn)  lbus_a  <= lbus_di_a;
   always @(posedge clk) if (~lbus_wrn) lbus_di <= lbus_di_a;

   (* KEEP_HIERARCHY = "TRUE" *)
   LBUS_IF lbus_if
     (.lbus_a(lbus_a), .lbus_di(lbus_di), .lbus_do(lbus_do),
      .lbus_wr(lbus_wrn), .lbus_rd(lbus_rdn),
      .blk_kin(blk_kin), .blk_din(blk_din), .blk_dout(blk_dout),
      .blk_krdy(blk_krdy), .blk_drdy(blk_drdy), 
      .blk_kvld(blk_kvld), .blk_dvld(blk_dvld),
      .blk_encdec(blk_encdec), .blk_en(blk_en), .blk_rstn(blk_rstn),
      .clk(clk), .rst(rst));

  //------------------------------------------------
  assign gpio_startn = 0;
  assign gpio_endn   = 1'b0; //~blk_dvld;
  assign gpio_exec   = 1'b0; //blk_busy;

  (* KEEP_HIERARCHY = "TRUE" *)
  FSM FSM (
    // BLK KEY INTERFACE
    .blk_kin     (blk_kin),
    .blk_krdy    (blk_krdy),
    .blk_kvld    (blk_kvld),
    
    // BLK DATA INTERFACE
    .blk_din     (blk_din),
    .blk_drdy    (blk_drdy),
    .blk_dout    (blk_dout),
    .blk_dvld    (blk_dvld),
    
    // AES KEY INTERFACE 
    .aes_kin     (aes_kin),
    .aes_krdy    (aes_krdy),
    .aes_kvld    (aes_kvld),
    
    // AES DATA INTERFACE
    .aes_din     (aes_din),
    .aes_drdy    (aes_drdy),
    .aes_busy    (aes_busy),
    .aes_dout    (aes_dout),
    .aes_dvld    (aes_dvld),
    
    // SENSOR FIFO INTERFACE
    .sens_trig   (sens_trig),
    .sens_dout   (sens_fifo_dout),
    .sens_drdy   (sens_fifo_drdy),
    .sens_dvld   (sens_fifo_dvld),

    // CALIBRATION INTERFACE
    .IDC_IDF   (IDC_IDF),
    .IDC_IDF_en  (IDC_IDF_en),

    .rst_n       (rst_system_n),
    .clk_i         (aes_clk)); 
   
  (* KEEP_HIERARCHY = "TRUE" *)
  AES_Comp AES_Comp(
    .Kin  (aes_kin), 
    .Krdy (aes_krdy),
    .Kvld (aes_kvld),
    .Din  (aes_din),
    .Drdy (aes_drdy),
    .Dout (aes_dout),
    .Dvld (aes_dvld),
    .EncDec (0),
    .EN   (1'b1),
    .BSY  (aes_busy),
    .CLK  (aes_clk),
    .RSTn (rst_system_n));

  (* KEEP_HIERARCHY = "TRUE" *)
  (* DONT_TOUCH = "TRUE" *)
  sensor_wrapper_top#(
    .COARSE_WIDTH     (32),
    .FINE_WIDTH       (24),
    .SENSOR_WIDTH     (32))
  sensor_top(
    .clk_i             (sensor_clk),
    .IDC_IDF_en_i      (IDC_IDF_en),
    .sensor_o          (sensor_output),//if sensor_o < SENSOR_WIDTH, then the most significant bits are padded with 0s
    .ID_coarse_i       (IDC_IDF[31:0]),
    .ID_fine_i         (IDC_IDF[127:32])
    );

     

  (* KEEP_HIERARCHY = "TRUE" *)
  sensor_fifo#(
    .N_SAMPLES(128))
  sensor_fifo(
    .sens_fifo_din  (sensor_output),
    .sens_fifo_trig (sens_trig),

    .sens_fifo_dout (sens_fifo_dout),
    .sens_fifo_drdy (sens_fifo_drdy),
    .sens_fifo_dvld (sens_fifo_dvld),

    .clk_wr         (sensor_clk),
    .clk_rd         (aes_clk),
    .reset_wr_n     (rst_sensor_n),
    .reset_rd_n     (rst_system_n));

  // CLK GEN
  clk_generator clk_generator(
    .sensor_clk (sensor_clk),
    .aes_clk    (aes_clk),
    .resetn     (1'b1), 
    .locked     (locked),
    .clk_in1    (clk));  

  reset_gen#(
    .N_RESETS(2))
  reset_gen(
    .reset_ext_in_n (blk_rstn),
    .reset_aux_in_n (1'b1),
    .locked         (locked),
    .clocks         ({aes_clk, sensor_clk}),
    .resets_out_n   ({rst_system_n, rst_sensor_n}),
    .resets_out_p    ({rst_system_p, rst_sensor_p}));
   //------------------------------------------------   
   MK_CLKRST mk_clkrst (.clkin(lbus_clkn), .rstnin(lbus_rstn),
                        .clk(clk), .rst(rst));

   //Add clock gen
endmodule // CHIP_SASEBO_GIII_AES


   
//================================================ MK_CLKRST
module MK_CLKRST (clkin, rstnin, clk, rst);
   //synthesis attribute keep_hierarchy of MK_CLKRST is no;
   
   //------------------------------------------------
   input  clkin, rstnin;
   output clk, rst;
   wire   refclk;

   //------------------------------------------------ clock
   IBUFG u10 (.I(clkin), .O(refclk)); 
   BUFG  u12 (.I(refclk),   .O(clk));

   //------------------------------------------------ reset
   MK_RST u20 (.locked(rstnin), .clk(clk), .rst(rst));
endmodule // MK_CLKRST



//================================================ MK_RST
module MK_RST (locked, clk, rst);
   //synthesis attribute keep_hierarchy of MK_RST is no;
   
   //------------------------------------------------
   input  locked, clk;
   output rst;

   //------------------------------------------------
   reg [15:0] cnt;
   
   //------------------------------------------------
   always @(posedge clk or negedge locked) 
     if (~locked)    cnt <= 16'h0;
     else if (~&cnt) cnt <= cnt + 16'h1;

   assign rst = ~&cnt;
endmodule // MK_RST


