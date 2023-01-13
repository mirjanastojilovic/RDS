
# RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
# Copyright 2023, School of Computer and Communication Sciences, EPFL.
#
# All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file. 
 

# define the C compiler to use
CC = gcc

# define any compile-time flags
CFLAGS = -Wall -g 

# define any directories containing header files other than /usr/include
#
INCLUDES = -I/usr/local/lib # -I"../FTD2xxDev/src"

# define library paths in addition to /usr/lib
#   if I wanted to include libraries not in /usr/lib I'd specify
#   their path using -Lpath, something like:
LDFLAGS = -L/usr/local/lib # -L../FTD2xxDev/Debug

# define any libraries to link into executable:
#   if I want to link in libraries (libx.so or libx.a) I use the -llibname 
#   option, something like (this will link in libmylib.so and libm.so:
LIBFLAGS =-pthread -lftd2xx 

# define the C source files
SRCS = Sasebogii.c main.c ftdi_interface.c aes.c utils.c oscilloscope.c aes_soft.c 



# define the C object files 
#
# This uses Suffix Replacement within a macro:
#   $(name:string1=string2)
#         For each word in 'name' replace 'string1' with 'string2'
# Below we are replacing the suffix .c of all words in the macro SRCS
# with the .o suffix
#
OBJS = $(SRCS:.c=.o)


# define the executable file 
MAIN = FTDexampleAES


#
# The following part of the makefile is generic; it can be used to 
# build any executable just by changing the definitions above and by
# deleting dependencies appended to the file from 'make depend'
#

.PHONY: depend clean

all: $(MAIN)
	@echo  Simple compiler named mycc has been compiled

$(MAIN): $(OBJS)
	$(CC) $(CFLAGS) $(INCLUDES)  -o Debug/$(MAIN) $(addprefix Debug/,$(OBJS)) $(LDFLAGS) $(LIBFLAGS)

# this is a suffix replacement rule for building .o's from .c's
# it uses automatic variables $<: the name of the prerequisite of
# the rule(a .c file) and $@: the name of the target of the rule (a .o file) 
# (see the gnu make manual section about automatic variables)
.c.o:
	mkdir -p Debug
	$(CC) $(CFLAGS) $(INCLUDES)  -c $<  -o Debug/$@

clean:
	$(RM) Debug/*.o 
	$(RM) Debug/$(MAIN)

depend: $(SRCS)
	makedepend $(INCLUDES) $^

# DO NOT DELETE THIS LINE -- make depend needs it

