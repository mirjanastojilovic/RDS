/*
 RDS: FPGA Routing Delay Sensors for Effective Remote Power Analysis Attacks
 Copyright 2023, School of Computer and Communication Sciences, EPFL.

 All rights reserved. Use of this source code is governed by a
 BSD-style license that can be found in the LICENSE.md file. 
 */

module AxiFlusher #(
    BRAM_DATA_WIDTH = 32,
    BRAM_ADDR_WIDTH = 12,
    WRITE_LENGTH = 2048
) (
    input wire [63:0]                     base_ptr,

    // BRAM side interfaces
    input wire [BRAM_DATA_WIDTH - 1 : 0]  douta,
    output wire [BRAM_ADDR_WIDTH - 1 : 0] addra,
    output wire                           ena,
    // control
    input wire                            start_dump,
    output wire                           dump_idle,

    // axi master write interface
    input wire                            aclk,
    input wire                            aresetn,

    output wire [63:0]                    awaddr,
    output wire [7:0]                     awlen,
    output wire [2:0]                     awsize,
    output wire                           awvalid,
    input wire                            awready,

    output wire [BRAM_DATA_WIDTH-1:0]     wdata,
    output wire [BRAM_DATA_WIDTH/8-1:0]   wstrb,
    output wire                           wvalid,
    output wire                           wlast,
    input wire                            wready,

    input wire [1:0]                      bresp,
    input wire                            bvalid,
    output wire                           bready

);

    // assign byte_addr = addra << ADDRESS_OFFSET;
    logic [63 : 0] byte_addr;
    logic  [63: 0] word_addr;
    localparam NUM_BYTES = BRAM_DATA_WIDTH / 8;
    localparam ADDRESS_OFFSET = $clog2(NUM_BYTES);

    typedef enum logic[3:0] { IDLE, ACCESS_BRAM, PUSH_ADDR, PUSH_DATA, WAIT_RESP, CHECK} StateType;

    StateType pstate = IDLE;
    StateType nstate;

    always_ff @(posedge aclk) begin
        if (~aresetn) begin
            pstate <= IDLE;
            byte_addr <= base_ptr;
            word_addr <= {64{1'b0}};
        end else begin
            pstate <= nstate;
            if (pstate == CHECK) begin
                byte_addr <= byte_addr + NUM_BYTES;
                word_addr <= word_addr + 1;
            end
            else if(pstate == IDLE) begin
                byte_addr <= base_ptr;
                word_addr <= {64{1'b0}};
            end
        end
    end

    always_comb begin

        nstate = IDLE;

        case (pstate)
            IDLE: if (start_dump) nstate = ACCESS_BRAM; else nstate = IDLE;
            ACCESS_BRAM:
                nstate = PUSH_ADDR;
            PUSH_ADDR:
                if (awready)
                    nstate = PUSH_DATA;
                else
                    nstate = PUSH_ADDR;
            PUSH_DATA:
                if (wready)
                    nstate = WAIT_RESP;
                else
                    nstate = PUSH_DATA;
            WAIT_RESP:
                if (bvalid) begin
                    nstate = CHECK;
                end else begin
                    nstate = WAIT_RESP;
                end
            CHECK:
                if (word_addr == (WRITE_LENGTH - 1))
                    nstate = IDLE;
                else
                    nstate = ACCESS_BRAM;
            default:
                nstate = IDLE;
        endcase

    end

    assign addra = word_addr;
    assign ena = (pstate != IDLE);

    assign dump_idle = (pstate == IDLE);

    assign awaddr = byte_addr;
    assign awvalid = (pstate == PUSH_ADDR);
    assign awsize = ADDRESS_OFFSET;
    assign awlen = 0;

    assign bready = 1'b1;

    assign wvalid = (pstate == PUSH_DATA);
    assign wlast = (pstate == PUSH_DATA);
    assign wstrb = {NUM_BYTES{1'b1}};
    assign wdata = douta;

endmodule
