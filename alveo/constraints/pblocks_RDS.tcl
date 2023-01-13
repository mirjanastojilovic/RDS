
# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# VICTIM PBLOCK
create_pblock VICTIM
resize_pblock VICTIM -add {SLICE_X0Y660:SLICE_X82Y899 DSP48E2_X0Y264:DSP48E2_X9Y359 RAMB18_X0Y264:RAMB18_X5Y359 RAMB36_X0Y132:RAMB36_X5Y179 URAM288_X0Y176:URAM288_X1Y239 }

# SEPARATION PBLOCK
create_pblock SEPARATION
resize_pblock SEPARATION -add {SLICE_X83Y660:SLICE_X84Y899 }
set_property EXCLUDE_PLACEMENT 1 [get_pblocks SEPARATION]

# AES PBLOCK
create_pblock AES
resize_pblock AES -add {SLICE_X65Y780:SLICE_X80Y809 }
add_cells_to_pblock AES [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/AES]] -clear_locs
set_property EXCLUDE_PLACEMENT 1 [get_pblocks AES]

# ATTACKER PBLOCK
create_pblock ATTACKER
resize_pblock ATTACKER -add {SLICE_X85Y660:SLICE_X168Y899 DSP48E2_X10Y264:DSP48E2_X18Y359 RAMB18_X6Y264:RAMB18_X11Y359 RAMB36_X6Y132:RAMB36_X11Y179 URAM288_X2Y176:URAM288_X3Y239 }
add_cells_to_pblock ATTACKER [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[*].IDC_reg[*][*]]] -clear_locs
add_cells_to_pblock ATTACKER [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[*].IDF_reg[*][*]]] -clear_locs
add_cells_to_pblock ATTACKER [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/trace_bram]] -clear_locs
add_cells_to_pblock ATTACKER [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/BramDumper]] -clear_locs

# CTRL PBLOCK
create_pblock CTRL
resize_pblock CTRL -add {SLICE_X0Y600:SLICE_X168Y659 DSP48E2_X0Y240:DSP48E2_X18Y263 RAMB18_X0Y240:RAMB18_X11Y263 RAMB36_X0Y120:RAMB36_X11Y131 URAM288_X0Y160:URAM288_X3Y175 }
add_cells_to_pblock CTRL [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/AxiBRAMFlusher]] -clear_locs
add_cells_to_pblock CTRL [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/AxiLiteFSM]] -clear_locs
add_cells_to_pblock CTRL [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/krdy_sync_unit]] -clear_locs
add_cells_to_pblock CTRL [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/aes_start_sync_unit]] -clear_locs

# Sensor 0
create_pblock sensor_0
resize_pblock sensor_0 -add {SLICE_X86Y780:SLICE_X86Y815}
add_cells_to_pblock sensor_0 [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[1].sensor/tdc0]] -clear_locs
set_property LOC SLICE_X86Y780 [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[1].sensor/tdc0/fine_init]]
set_property DONT_TOUCH true [get_cells [list level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[1].sensor/tdc0/*]]
set_property EXCLUDE_PLACEMENT 1 [get_pblocks sensor_0]

create_pblock pblock_REGISTERS
add_cells_to_pblock [get_pblocks pblock_REGISTERS] [get_cells level0_i/ulp/AES_SCA_kernel_1/U0/sensors/sensor_gen[1].sensor/tdc0/sensor_o_regs[*].obs_regs]
resize_pblock [get_pblocks pblock_REGISTERS] -add {SLICE_X88Y780:SLICE_X91Y787}   
set_property EXCLUDE_PLACEMENT 1 [get_pblocks pblock_REGISTERS]
