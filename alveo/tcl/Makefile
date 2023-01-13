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


impl_tdc:
	./package.sh -mode=1 -sensor=0 | tee package.log && ./impl.sh -sensor=0 | tee impl.log

package_tdc: 
	./package.sh -mode=1 -sensor=0 | tee package.log

impl_rds:
	./package.sh -mode=1 -sensor=1 | tee package.log && ./impl.sh -sensor=1 | tee impl.log

package_rds: 
	./package.sh -mode=1 -sensor=1 | tee package.log

sim:
	./package.sh -mode=0 | tee package.log && ./sim.sh | tee sim.log

clean:
	rm -rf v++*.log vivado*.log vivado*.jou x*.log packaged temp_packaged bin _x .Xil kernel.xo impl.log package.log sim.log
