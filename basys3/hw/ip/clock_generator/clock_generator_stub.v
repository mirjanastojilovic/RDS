// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
// Date        : Wed Apr  7 18:15:32 2021
// Host        : glamocan-XPS-15-7590 running 64-bit Ubuntu 18.04.5 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/glamocan/work/teaching/semester_projects/ap_20/code/vivado/t_test_uart_v3/t_test_uart_v3.srcs/sources_1/ip/clock_generator/clock_generator_stub.v
// Design      : clock_generator
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tcpg236-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module clock_generator(aes_clk, sensor_clk, ttest_clk, resetn, locked, 
  clk_in1)
/* synthesis syn_black_box black_box_pad_pin="aes_clk,sensor_clk,ttest_clk,resetn,locked,clk_in1" */;
  output aes_clk;
  output sensor_clk;
  output ttest_clk;
  input resetn;
  output locked;
  input clk_in1;
endmodule
