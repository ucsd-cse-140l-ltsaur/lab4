
// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2019 by UCSD CSE 140L
// --------------------------------------------------------------------
//
// Permission:
//
//   This code for use in UCSD CSE 140L.
//   It is synthesisable for Lattice iCEstick 40HX.  
//
// Disclaimer:
//
//   This Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  
//
// -------------------------------------------------------------------- //           
//                     Lih-Feng Tsaur
//                     Bryan Chin
//                     UCSD CSE Department
//                     9500 Gilman Dr, La Jolla, CA 92093
//                     U.S.A
//
// --------------------------------------------------------------------

//
// uncomment this define if you want to target hardware
// otherwise, this file will be configured for the simulator
//
`define HW

//
// Revision History : 0.0
//

   
`ifdef HW

module inpin(
  input clk,
  input pin,
  output rd);

  SB_IO #(.PIN_TYPE(6'b0000_00)) _io (
        .PACKAGE_PIN(pin),
        .INPUT_CLK(clk),
        .D_IN_0(rd));
endmodule
`endif


// -----------------------------------
//
// reset generator
//    
// when esc key is detected, generates a reset signal for 16 cycles
//
//
//
module resetGen(
         output reg  rst, // global reset		 
		 input 	     bu_rx_data_rdy, // data from uart rdy
		 input [7:0] bu_rx_data, // data from uart
		 input       tb_sim_rst,   // simulation reset
		 input 	     clk
		 );
   
   
   reg [5-1:0] 		     reset_count;
   wire 		     escKey = bu_rx_data_rdy & (bu_rx_data == 8'h1b);
   
   wire [5-1:0] reset_count_next;
   defparam uu0.N = 5;
   N_bit_counter uu0(
   .result (reset_count_next[5-1:0])       , // Output
   .r1 (reset_count[5-1:0])                  , // input
   .up (1'b1)
   );
   
   always @(posedge clk) begin
      rst <= ~reset_count[4];
	  reset_count <= (tb_sim_rst | escKey)? 5'b00000 :
	               (reset_count[4])? reset_count: reset_count_next;
   end // always @ (posedge clk_in)
endmodule

// -----------------------------------
//
// top level for lab3
//
module latticehx1k(
		   output 	sd,
 	     
		   input 	clk_in,
		   input wire 	from_pc,
		   output wire 	to_ir,
		   output wire 	o_serial_data,
		   output [4:0] led
				
				
`ifndef HW
		   // for software only
		   ,input 	tb_sim_rst
		   ,input [7:0]	tb_rx_data // pretend data coming from the uart
		   ,input 	tb_rx_data_rdy //
		   ,output [7:0] ut_tx_data
		   ,output ut_tx_data_rdy

`endif

	);
`ifndef HW
   assign ut_tx_data =8'b0;
   assign ut_tx_data_rdy = 1'b0;
`endif

   wire 			clk;
   wire 			rst;
 			
`ifdef HW
   wire tb_sim_rst = 1'b0;
   
   assign to_ir = 1'b0;
   assign sd = 1'b0;

   wire PLLOUTGLOBAL;
   latticehx1k_pll latticehx1k_pll_inst(.REFERENCECLK(clk_in),
                                     .PLLOUTCORE(clk),
                                     .PLLOUTGLOBAL(PLLOUTGLOBAL),
                                     .RESET(1'b1));
									 
`else // !`ifdef HW
   fake_pll uut (
                         .REFERENCECLK(clk_in),
                         .PLLOUTCORE(clk),
		         .PLLOUTGLOBAL(),
                         .RESETB(1'b1),
                         .BYPASS(1'b0)
                        );
   
`endif

   wire [7:0] 	bu_rx_data;         // data from uart to dev
   wire  	    bu_rx_data_rdy;     // data from uart to dev is valid
   wire [7:0] 	bu_tx_data;         // data from dev to host
   wire 	    bu_tx_data_rdy;     // data from dev to host is ready 
   wire         bu_tx_busy;
   

`ifdef HW

   wire 	    uart_RXD;
   
   inpin _rcxd(.clk(clk), .pin(from_pc), .rd(uart_RXD));

   // with 12 MHz clock, 115600 baud, 8, N, 1
   buart buart (
		.clk (clk),
		.resetq(~rst),
		.rx(uart_RXD),
		.tx(o_serial_data),
		.rd(1'b1),                // read strobe
		.wr(bu_tx_data_rdy),	  // write strobe 
		.valid(bu_rx_data_rdy),   // rx has valid data
        .busy(bu_tx_busy),
		.tx_data(bu_tx_data),
		.rx_data(bu_rx_data)
		);

`else // !`ifdef HW
   fake_buart buart (
		.clk (clk),
		.resetq(tb_sim_rst),
		.rx(from_pc),
		.tx(o_serial_data),
		.rd(1'b1),                // read strobe
		.wr(1'b0),                // write strobe 
		.valid(bu_rx_data_rdy),   // rx has valid data
        .busy(bu_tx_busy),        // uart is busy transmitting
		.tx_data(8'b0),
		.rx_data(bu_rx_data),
  	    .fa_data(),
		.fa_valid(),
		.to_dev_data(tb_rx_data),
		.to_dev_data_valid(tb_rx_data_rdy));
`endif



   //
   // reset generation
   //
   resetGen resetGen(
		     .rst(rst),
		     .bu_rx_data_rdy(bu_rx_data_rdy),
		     .bu_rx_data(bu_rx_data),
		     .tb_sim_rst(tb_sim_rst),
		     .clk(clk)
		     );
   

   wire [4:0] 	    L4_led;
   assign led[4:0] = L4_led[4:0];
   

lab4 lab_u0(
.clk(clk),
.rst(rst),
.bu_rx_data_rdy(bu_rx_data_rdy),
.bu_rx_data(bu_rx_data),
.bu_tx_busy(bu_tx_busy),

.bu_tx_data(bu_tx_data),
.bu_tx_data_rdy(bu_tx_data_rdy),
.led(L4_led)
);


endmodule // latticehx1k
