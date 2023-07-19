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
set src_path ../hw
set src_path [file normalize $src_path]

# Create vivado project with the desired name
create_project -name $project_name

# Change the FPGA used to the one on Amazon F1
set_property part xc7a35tcpg236-1 [current_project]
# Change the default language to VHDL
set_property target_language VHDL [current_project]

# Import source files
import_files -norecurse "$src_path/rtl/AES_Comp.v" \
			"$src_path/rtl/read_traces.vhd" \
                        "$src_path/rtl/sig_delay.vhd" \
                        "$src_path/rtl/io_wrapper.vhd" \
                        "$src_path/rtl/reset_wrapper.vhd" \
                        "$src_path/rtl/xadc.vhd"  \
                        "$src_path/rtl/system_top_artix7_fifo_aes.vhd" \
                        "$src_path/rtl/packages/design_package.vhd" \
                        "$src_path/rtl/general/BRAM_dual_clock.vhd" \
                        "$src_path/rtl/general/counter_up.vhd" \
			"$src_path/rtl/general/FSM_FIFO.vhd" \
                        "$src_path/rtl/uart/UART.vhd" \
                        "$src_path/rtl/uart/rxuartlite.v" \
                        "$src_path/rtl/uart/txuartlite.v" \
                        "$src_path/rtl/io_controller/address_dec.vhd" \
                        "$src_path/rtl/io_controller/config_registers.vhd" \
                        "$src_path/rtl/io_controller/data_dec.vhd" \
                        "$src_path/rtl/io_controller/data_enc.vhd" \
                        "$src_path/rtl/io_controller/io_fsm_fifo_aes.vhd" \
                        "$src_path/rtl/io_controller/io_controller_fifo_aes.vhd" \
                        "$src_path/rtl/sensor/sensor_top.vhd" \
                        "$src_path/rtl/sensor/sensor.vhd"


update_compile_order -fileset sources_1
update_compile_order -fileset sources_1

import_files "$src_path/ip/clock_generator/clock_generator.xci" \
             "$src_path/ip/reset_gen/reset_gen.xci" \
             "$src_path/ip/fifo_generator_0/fifo_generator_0.xci"

export_ip_user_files -of_objects  [get_files  {$project_name.srcs/sources_1/ip/fifo_generator_0/fifo_generator_0.xci $project_name.srcs/sources_1/ip/clock_generator/clock_generator.xci $project_name.srcs/sources_1/ip/reset_gen/reset_gen.xci $project_name.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci}] -lib_map_path [list {modelsim=$project_name.cache/compile_simlib/modelsim} {questa=$project_name.cache/compile_simlib/questa} {ies=$project_name.cache/compile_simlib/ies} {xcelium=$project_name.cache/compile_simlib/xcelium} {vcs=$project_name.cache/compile_simlib/vcs} {riviera=$project_name.cache/compile_simlib/riviera}] -force -quiet

update_compile_order -fileset sources_1

# Import constraint files
add_files -fileset constrs_1 -norecurse "$src_path/xdc/constraints_RDS.xdc"
import_files -fileset constrs_1 "$src_path/xdc/constraints_RDS.xdc"

# Change clk frequency to 50 MHz

set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} CONFIG.OVERRIDE_MMCM {true} CONFIG.MMCM_DIVCLK_DIVIDE {1} CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} CONFIG.CLKOUT1_JITTER {151.636}] [get_ips clock_generator]
generate_target all [get_files  $work_dir/$project_name.srcs/sources_1/ip/clock_generator/clock_generator.xci]

# Turn on timing optimizations
#set_property strategy Performance_ExtraTimingOpt [get_runs impl_1]

