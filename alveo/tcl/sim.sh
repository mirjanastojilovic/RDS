#!/bin/bash
# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

JOBS=""
PLATFORM=""

if [ "$1" = "" ]
then
  echo "No arguments. Use --help for more info."
  exit 1
fi

for i in "$@"
do
case $i in
    -jobs=*|--JOBS_NUMBER=*)
    JOBS="${i#*=}"
    shift
    ;;
    -platform=*|--PLATFORM=*)
    PLATFORM="${i#*=}"
    shift
    ;;
    -h |--help)
    echo -e "-jobs     | --JOBS_NUMBER    : number of jobs. \n\t"
    echo -e "-platform | --PLATFORM       : platform specification. \n\t"
    echo -e "-h        | --help           : display help."
    exit 1
    shift
    ;;
    *)
    echo "Unknown option: $i. Try --help."
    shift # unknown option
    exit 1
    ;;
esac
done

export XCL_EMULATION_MODE=hw_emu
v++ --link -t hw_emu -g --platform $PLATFORM --save-temps \
  --vivado.synth.jobs $JOBS --vivado.impl.jobs $JOBS \
  --kernel_frequency 0:200 -o bin/picorv_sca.xclbin kernel.xo
  #--vivado.prop run.impl_1.STEPS.PLACE_DESIGN.TCL.PRE=pblocks.tcl \
