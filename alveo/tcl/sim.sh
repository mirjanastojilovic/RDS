#!/bin/bash
# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

export XCL_EMULATION_MODE=hw_emu
v++ --link -t hw_emu -g --platform xilinx_u200_gen3x16_xdma_1_202110_1 --save-temps \
  --vivado.synth.jobs 24 --vivado.impl.jobs 24 \
  --kernel_frequency 0:200 -o bin/picorv_sca.xclbin kernel.xo
  #--vivado.prop run.impl_1.STEPS.PLACE_DESIGN.TCL.PRE=pblocks.tcl \
