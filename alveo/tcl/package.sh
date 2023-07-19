# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

MODE=""
SENSOR=""
PLATFORM=""

if [ "$1" = "" ]
then
  echo "No arguments. Use --help for more info."
  exit 1
fi

for i in "$@"
do
case $i in
    -mode=*|--PACKAGE_MODE=*)
    MODE="${i#*=}"
    shift
    ;;
    -sensor=*|--SENSOR_TYPE=*)
    SENSOR="${i#*=}"
    shift
    ;;
    -platform=*|--PLATFORM=*)
    PLATFORM="${i#*=}"
    shift
    ;;
    -h |--help)
    echo -e "-mode     | --PACKAGE_MODE   : package mode specification.\n\t- 0 : package for simulation\n\t- 1 : package for implementation\n\tExample: -mode=1"
    echo -e "-sensor   | --SENSOR_TYPE    : sensor type specification.\n\t- 0 : use TDC sensor\n\t- 1 : use RDS sensor\n\tExample: -sensor=1"
    echo -e "-platform | --PLATFORM       : platform type specification. \n\t"
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

vivado -mode batch -source gen_xo.tcl -notrace -tclargs kernel.xo AES_SCA_kernel hw $PLATFORM $MODE $SENSOR 
