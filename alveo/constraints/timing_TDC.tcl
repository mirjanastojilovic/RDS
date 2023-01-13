# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

set_false_path -from [get_clocks *] -to [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[*].sensor/tdc0/sensor_o_regs[*].obs_regs/D}]
set_false_path -from [get_clocks *] -to [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[*].sensor/tdc0/sensor_o_regs[*].obs_regs/D}]

set_false_path -from [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/AxiLiteFSM/pt_reg_reg[*]/C}] -to [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/AES/AES_Comp_ENC/Drg_reg[*]/D}]
set_false_path -from [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/AxiLiteFSM/key_reg_reg[*]/C}] -to [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/AES/AES_Comp_ENC/KrgX_reg[*]/D}]
set_false_path -from [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/AxiLiteFSM/key_reg_reg[*]/C}] -to [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/AES/AES_Comp_ENC/Krg_reg[*]/D}]


#set_false_path -from [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/CPU/inst_fetched_reg[*]/C}] -to [get_pins {level0_i/ulp/AES_SCA_kernel_1/U0/trace_bram/U0/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[*].ram.r/prim_init.ram/DEVICE_8SERIES.NO_BMM_INFO.TRUE_DP.SIMPLE_PRIM36.ram/DINADIN[*]}]
