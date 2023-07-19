# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

.PHONY: check-env

check-env:
ifndef XILINX_XRT
	$(error XILINX_XRT is undefined)
endif

jobs = 24
platform = xilinx_u200_gen3x16_xdma_1_202110_1 


impl_tdc:
	./package.sh -mode=1 -sensor=0 -platform=$(platform) | tee package.log && ./impl.sh -sensor=0 -platform=$(platform) -jobs=$(jobs) | tee impl.log

package_tdc: 
	./package.sh -mode=1 -sensor=0 -platform=$(platform) | tee package.log

impl_rds:
	./package.sh -mode=1 -sensor=1 -platform=$(platform) | tee package.log && ./impl.sh -sensor=1 -platform=$(platform) -jobs=$(jobs) | tee impl.log

package_rds: 
	./package.sh -mode=1 -sensor=1 -platform=$(platform) | tee package.log

sim:
	./package.sh -mode=0 -platform=$(platform)           | tee package.log && ./sim.sh -platform=$(platform) -jobs=$(jobs) | tee sim.log

clean:
	rm -rf v++*.log vivado*.log vivado*.jou x*.log packaged temp_packaged bin _x .Xil kernel.xo impl.log package.log sim.log
