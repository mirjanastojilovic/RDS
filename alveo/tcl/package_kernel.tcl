#
# Copyright (C) 2019-2021 Xilinx, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may
# not use this file except in compliance with the License. A copy of the
# License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
set sim    [lindex $::argv 0]
set sensor [lindex $::argv 1]

set path_to_hdl ./../rtl
set path_to_packaged ./packaged
set path_to_tmp_project ./temp_packaged
set master_interface_0 m_axi_bank_0
# set master_interface_1 m_axi_bank_1
# set master_interface_2 m_axi_bank_2
# set master_interface_3 m_axi_bank_3
set slave_interface s_axi_control


create_project -force kernel_pack $path_to_tmp_project
add_files -norecurse [glob $path_to_hdl/AxiFlusher.sv \
                           $path_to_hdl/AxiLoader.vhd \
                           $path_to_hdl/BramDumper.vhd \
                           $path_to_hdl/URAMLike.v \
                           $path_to_hdl/AES_Comp.v \
                           $path_to_hdl/counter_simple.vhd \
                           $path_to_hdl/cross_clk_sync.vhd \
                           $path_to_hdl/design_package.vhd \
                           $path_to_hdl/AES_SCA_kernel.vhd \
                           $path_to_hdl/AxiLiteFSM.vhd \
                           $path_to_hdl/sensor/sensor_top.vhd \
                           $path_to_hdl/sensor/sensor_top_multiple.vhd]

if {$sim eq "0"} {
  puts "PACKAGING FOR SIMULATION"
  add_files -norecurse [glob $path_to_hdl/sensor/sensor_sim.vhd]
} else {
  puts "PACKAGING FOR IMPLEMENTATION"
  if {$sensor eq "0"} {
    puts "USING TDC"
    add_files -norecurse [glob $path_to_hdl/sensor/sensor_TDC.vhd]
  } else {
    puts "USING RDS"
    add_files -norecurse [glob $path_to_hdl/sensor/sensor_RDS.vhd]
  }
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name trace_bram
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} CONFIG.Use_Byte_Write_Enable {true} CONFIG.Byte_Size {8} CONFIG.Write_Width_A {512} CONFIG.Write_Depth_A {4096} CONFIG.Read_Width_A {512} CONFIG.Write_Width_B {512} CONFIG.Read_Width_B {512} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Register_PortB_Output_of_Memory_Primitives {true} CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Port_B_Clock {100} CONFIG.Port_B_Write_Rate {50} CONFIG.Port_B_Enable_Rate {100}] [get_ips trace_bram]

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name memory_bram
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} CONFIG.Use_Byte_Write_Enable {true} CONFIG.Byte_Size {8} CONFIG.Write_Width_A {32} CONFIG.Write_Depth_A {8192} CONFIG.Read_Width_A {32} CONFIG.Write_Width_B {32} CONFIG.Read_Width_B {32} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Register_PortB_Output_of_Memory_Primitives {false} CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Port_B_Clock {100} CONFIG.Port_B_Write_Rate {50} CONFIG.Port_B_Enable_Rate {100}] [get_ips memory_bram]

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clock_generator 
set_property -dict [list CONFIG.PRIM_IN_FREQ {200.000} CONFIG.CLKOUT2_USED {true} CONFIG.PRIMARY_PORT {axi_clk} CONFIG.CLK_OUT1_PORT {aes_clk} CONFIG.CLK_OUT2_PORT {sens_clk} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {20.000} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} CONFIG.RESET_TYPE {ACTIVE_LOW} CONFIG.CLKIN1_JITTER_PS {50.0} CONFIG.MMCM_CLKFBOUT_MULT_F {5.000} CONFIG.MMCM_CLKIN1_PERIOD {5.000} CONFIG.MMCM_CLKIN2_PERIOD {10.0} CONFIG.MMCM_CLKOUT0_DIVIDE_F {50.000} CONFIG.MMCM_CLKOUT1_DIVIDE {5} CONFIG.NUM_OUT_CLKS {2} CONFIG.RESET_PORT {resetn} CONFIG.CLKOUT1_JITTER {155.330} CONFIG.CLKOUT1_PHASE_ERROR {89.971} CONFIG.CLKOUT2_JITTER {98.146} CONFIG.CLKOUT2_PHASE_ERROR {89.971}] [get_ips clock_generator]
set_property -dict [list CONFIG.CLKOUT2_USED {false} CONFIG.MMCM_CLKFBOUT_MULT_F {4.250} CONFIG.MMCM_CLKOUT0_DIVIDE_F {42.500} CONFIG.MMCM_CLKOUT1_DIVIDE {1} CONFIG.NUM_OUT_CLKS {1} CONFIG.CLKOUT1_JITTER {155.788} CONFIG.CLKOUT1_PHASE_ERROR {94.329}] [get_ips clock_generator]

create_ip -name proc_sys_reset -vendor xilinx.com -library ip -version 5.0 -module_name rst_gen
set_property -dict [list CONFIG.Component_Name {rst_gen} CONFIG.C_EXT_RST_WIDTH {1} CONFIG.C_AUX_RST_WIDTH {1} CONFIG.C_EXT_RESET_HIGH {0} CONFIG.C_AUX_RESET_HIGH {0}] [get_ips rst_gen]

create_ip -name axi_register_slice -vendor xilinx.com -library ip -version 2.1 -module_name axi_full_register_slice
set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.DATA_WIDTH {512} CONFIG.REG_AW {10} CONFIG.REG_AR {10} CONFIG.REG_W {10} CONFIG.REG_R {10} CONFIG.REG_B {10} CONFIG.SUPPORTS_NARROW_BURST {0} CONFIG.HAS_BURST {0} CONFIG.HAS_LOCK {0} CONFIG.HAS_CACHE {0} CONFIG.HAS_REGION {0} CONFIG.HAS_QOS {0} CONFIG.HAS_PROT {0}] [get_ips axi_full_register_slice]

create_ip -name axi_register_slice -vendor xilinx.com -library ip -version 2.1 -module_name axi_lite_register_slice
set_property -dict [list CONFIG.PROTOCOL {AXI4LITE} CONFIG.ADDR_WIDTH {12} CONFIG.REG_AW {10} CONFIG.REG_AR {10} CONFIG.REG_W {10} CONFIG.REG_R {10} CONFIG.REG_B {10} CONFIG.SUPPORTS_NARROW_BURST {0} CONFIG.HAS_BURST {0} CONFIG.HAS_LOCK {0} CONFIG.HAS_CACHE {0} CONFIG.HAS_REGION {0} CONFIG.HAS_QOS {0} CONFIG.HAS_PROT {0}] [get_ips axi_lite_register_slice]

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
#set_property -dict [list CONFIG.C_PROBE26_WIDTH {32} CONFIG.C_PROBE25_WIDTH {512} CONFIG.C_PROBE24_WIDTH {512} CONFIG.C_PROBE23_WIDTH {32} CONFIG.C_PROBE21_WIDTH {64} CONFIG.C_PROBE20_WIDTH {12} CONFIG.C_PROBE13_WIDTH {12} CONFIG.C_PROBE12_WIDTH {64} CONFIG.C_PROBE9_WIDTH {2} CONFIG.C_PROBE6_WIDTH {64} CONFIG.C_PROBE5_WIDTH {512} CONFIG.C_PROBE2_WIDTH {3} CONFIG.C_PROBE1_WIDTH {8} CONFIG.C_PROBE0_WIDTH {64} CONFIG.C_DATA_DEPTH {2048} CONFIG.C_NUM_OF_PROBES {29}] [get_ips ila_0]
set_property -dict [list CONFIG.C_PROBE42_WIDTH {32} CONFIG.C_PROBE41_WIDTH {13} CONFIG.C_PROBE39_WIDTH {32} CONFIG.C_PROBE35_WIDTH {512} CONFIG.C_PROBE34_WIDTH {3} CONFIG.C_PROBE33_WIDTH {8} CONFIG.C_PROBE30_WIDTH {64} CONFIG.C_PROBE26_WIDTH {32} CONFIG.C_PROBE25_WIDTH {512} CONFIG.C_PROBE24_WIDTH {512} CONFIG.C_PROBE23_WIDTH {32} CONFIG.C_PROBE21_WIDTH {64} CONFIG.C_PROBE20_WIDTH {12} CONFIG.C_PROBE13_WIDTH {12} CONFIG.C_PROBE12_WIDTH {64} CONFIG.C_PROBE9_WIDTH {2} CONFIG.C_PROBE6_WIDTH {64} CONFIG.C_PROBE5_WIDTH {512} CONFIG.C_PROBE2_WIDTH {3} CONFIG.C_PROBE1_WIDTH {8} CONFIG.C_PROBE0_WIDTH {64} CONFIG.C_DATA_DEPTH {2048} CONFIG.C_NUM_OF_PROBES {43}] [get_ips ila_0]

ipx::package_project -root_dir $path_to_packaged -vendor parsa.epfl.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
ipx::unload_core $path_to_packaged/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $path_to_packaged $path_to_packaged/component.xml

set core [ipx::current_core]

set_property core_revision 2 $core
foreach up [ipx::get_user_parameters] {
  ipx::remove_user_parameter [get_property NAME $up] $core
}
ipx::associate_bus_interfaces -busif $master_interface_0 -clock ap_clk $core
ipx::associate_bus_interfaces -busif $slave_interface -clock ap_clk $core


set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} $core
set_property sdx_kernel true $core
set_property sdx_kernel_type rtl $core
set_property supported_families { } $core
set_property auto_family_support_level level_2 $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity -kernel $core
ipx::save_core $core
close_project -delete
