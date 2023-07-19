#!/bin/bash

# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

SENSOR=""
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
    -sensor=*|--SENSOR_TYPE=*)
    SENSOR="${i#*=}"
    shift
    ;;
    -jobs=*|--JOBS_NUMBER=*)
    JOBS="${i#*=}"
    shift
    ;;
    -platform=*|--PLATFORM=*)
    PLATFORM="${i#*=}"
    shift
    ;;
    -h |--help)
    echo -e "-sensor   | --SENSOR_TYPE    : sensor type specification.\n\t- 0 : use TDC sensor\n\t- 1 : use RDS sensor\n\tExample: -sensor=1"
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

if [ "$SENSOR" -eq "0" ]; then
    echo "IMPLEMENTING WITH TDC";
    v++ --link -t hw --platform $PLATFORM --save-temps \
      --vivado.prop run.impl_1.STEPS.OPT_DESIGN.TCL.PRE=../constraints/timing_TDC.tcl \
      --vivado.prop run.impl_1.STEPS.PLACE_DESIGN.TCL.PRE=../constraints/pblocks_TDC.tcl \
      --vivado.synth.jobs $JOBS --vivado.impl.jobs $JOBS \
      --kernel_frequency 0:200 -o bin/picorv_sca.xclbin kernel.xo
    #  --vivado.impl.strategies "Performance_ExplorePostRoutePhysOpt,Performance_ExtraTimingOpt" \
else
   echo "IMPLEMENTING WITH RDS";
    v++ --link -t hw --platform $PLATFORM --save-temps \
      --vivado.prop run.impl_1.STEPS.OPT_DESIGN.TCL.PRE=../constraints/timing_RDS.tcl \
      --vivado.prop run.impl_1.STEPS.PLACE_DESIGN.TCL.PRE=../constraints/pblocks_RDS.tcl \
      --vivado.synth.jobs $JOBS --vivado.impl.jobs $JOBS \
      --kernel_frequency 0:200 -o bin/picorv_sca.xclbin kernel.xo
    #  --vivado.impl.strategies "Performance_ExplorePostRoutePhysOpt,Performance_ExtraTimingOpt" \
fi

