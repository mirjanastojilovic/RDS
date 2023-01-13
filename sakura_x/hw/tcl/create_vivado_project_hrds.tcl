# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.
	

# Check if project name is defined
if {![info exists project_name]} {
  puts "Project name not defined.\nDefine project name with:\n\t set project_name your_project_name"
  return
}

# Create a directory with the project
exec mkdir $project_name

# Make that directory the current working directory
cd $project_name
set work_dir [pwd]
puts "The new working directory is [pwd]"

# Set sources path
set src_path ../..

# Create vivado project with the desired name
create_project -name $project_name

# Change the FPGA used to the one on Amazon F1
set_property part xc7k160tfbg676-1 [current_project]
# Change the default language to VHDL
set_property target_language Verilog [current_project]

# Import source files
import_files -norecurse "$src_path/sources/AES_Comp.v" \
                        "$src_path/sources/HRDS/chip_sasebo_giii_aes.v" \
                        "$src_path/sources/sensor_fifo.vhd" \
                        "$src_path/sources/FSM.vhd" \
                        "$src_path/sources/reset_gen.vhd" \
                        "$src_path/sources/packages/design_package.vhd" \
                        "$src_path/sources/HRDS/sensor.vhd" \
                        "$src_path/sources/HRDS/sensor_top.vhd" \
                        "$src_path/sources/HRDS/sensor_wrapper_top.vhd" \
                        "$src_path/sources/HRDS/counter_small.vhd" \
                        "$src_path/sources/lbus_if.v"  \
                        
update_compile_order -fileset sources_1
update_compile_order -fileset sources_1

# Import constraint files
add_files -fileset constrs_1 -norecurse "$src_path/constraints/HRDS/pin_sasebo_giii_k7.xdc"
import_files -fileset constrs_1 "$src_path/constraints/HRDS/pin_sasebo_giii_k7.xdc"

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_generator
set_property -dict [list CONFIG.PRIM_IN_FREQ {20.000} CONFIG.CLKOUT2_USED {true} CONFIG.CLK_OUT1_PORT {sensor_clk} CONFIG.CLK_OUT2_PORT {aes_clk} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {20.000} CONFIG.RESET_TYPE {ACTIVE_LOW} CONFIG.CLKIN1_JITTER_PS {500.0} CONFIG.MMCM_DIVCLK_DIVIDE {1} CONFIG.MMCM_CLKFBOUT_MULT_F {50.000} CONFIG.MMCM_CLKIN1_PERIOD {50.000} CONFIG.MMCM_CLKIN2_PERIOD {10.0} CONFIG.MMCM_CLKOUT0_DIVIDE_F {5.000} CONFIG.MMCM_CLKOUT1_DIVIDE {50} CONFIG.NUM_OUT_CLKS {2} CONFIG.RESET_PORT {resetn} CONFIG.CLKOUT1_JITTER {237.367} CONFIG.CLKOUT1_PHASE_ERROR {301.005} CONFIG.CLKOUT2_JITTER {382.942} CONFIG.CLKOUT2_PHASE_ERROR {301.005}] [get_ips clk_generator]
generate_target {instantiation_template} [get_files $work_dir/$project_name.srcs/sources_1/ip/clk_generator/clk_generator.xci] 

create_ip -name proc_sys_reset -vendor xilinx.com -library ip -version 5.0 -module_name reset_generator
set_property -dict [list CONFIG.Component_Name {reset_generator} CONFIG.C_EXT_RST_WIDTH {1} CONFIG.C_AUX_RST_WIDTH {1} CONFIG.C_EXT_RESET_HIGH {0} CONFIG.C_AUX_RESET_HIGH {0}] [get_ips reset_generator]
generate_target {instantiation_template} [get_files $work_dir/$project_name.srcs/sources_1/ip/reset_generator/reset_generator.xci]
update_compile_order -fileset sources_1

# Create the data FIFO IP 
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name fifo_generator_0
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} CONFIG.Input_Data_Width {128} CONFIG.Input_Depth {256} CONFIG.Output_Data_Width {128} CONFIG.Output_Depth {256} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Full_Flags_Reset_Value {1} CONFIG.Valid_Flag {true} CONFIG.Write_Acknowledge_Flag {true} CONFIG.Data_Count_Width {8} CONFIG.Write_Data_Count_Width {8} CONFIG.Read_Data_Count_Width {8} CONFIG.Full_Threshold_Assert_Value {253} CONFIG.Full_Threshold_Negate_Value {252} CONFIG.Enable_Safety_Circuit {true}] [get_ips fifo_generator_0]
generate_target {instantiation_template} [get_files $work_dir/$project_name.srcs/sources_1/ip/fifo_generator_0/fifo_generator_0.xci]
