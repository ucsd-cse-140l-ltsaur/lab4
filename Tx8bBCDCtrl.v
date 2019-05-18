//--------------------------
module Tx8Bits (
input  wire       clk,
input  wire       rst,
// input data
input  wire       tx_en,    //enable, high to let module access bus
input  wire       tx_start, //strob
input  wire       tx_CRLF,
input  wire       tx_BCD,
input  wire [7:0] in_data,
input  wire       bu_tx_busy,
// output data
output wire [7:0] bu_tx_data,
output wire       bu_tx_data_rdy,
output reg        tx_done,
output wire [4:0] led
);
reg [4:0] led_reg;
assign led = led_reg;
//---------- MUX control tx or high z ----------
assign bu_tx_data = (tx_en)? tx_data_byte: 8'bz;
assign bu_tx_data_rdy = (tx_en)? tx_strob: 1'bz;
//-------------------------------------------

parameter TX_IDLE     = 4'b0000, 
          TX_1st_BYTE = 4'b0001, TX_1st_ACTIVE = 4'b0010,
		  TX_2nd_BYTE = 4'b0011,
          TX_CRLF     = 4'b0100, TX_CR_ACTIVE  = 4'b0101,
		  TX_LF       = 4'b0110,
          TX_ASCII    = 4'b0111, 
		  TX_ACTIVE   = 4'b1000, TX_DONE      = 4'b1001;

reg [3:0] tx_state, tx_state_next;
reg       tx_proc;
reg       tx_finish;

// tx_dly = 00(start) -> 01 (strob) -> 10 (move to new state) -> 00
reg [1:0] tx_dly;
reg [2:0] tx_finish_dly;
wire[1:0] tx_dly_next = {tx_dly[0],  tx_proc};
wire      tx_strob = tx_dly[0] & ~tx_dly[1];
wire[2:0] tx_finish_dly_next  = {tx_finish_dly[1:0], tx_finish};
wire      tx_finish_dly2clk = &tx_finish_dly;
// latch in data at tx_start strob
reg [7:0] in_data_reg;

wire[3:0] nibble = (tx_state == TX_1st_BYTE)? in_data_reg[3:0]:in_data_reg[7:4];
wire[7:0] n2bcd  = nibble2BCD(nibble);
reg[7:0] tx_data_byte;

function [7:0] nibble2BCD;
input [3:0] i_nibble;
reg binAbove9;
begin
    binAbove9 = (i_nibble[3] & |i_nibble[2:1]);
    nibble2BCD[7:0] = (binAbove9) ? 
        {4'h4, 1'b0, (i_nibble[2] & |i_nibble[1:0]), ~(^i_nibble[1:0]), ~i_nibble[0]} : 
        {4'h3, i_nibble[3:0]};
end
endfunction

// actions
always @ (posedge clk) begin
    if(rst) begin
	    led_reg <= 5'h00;
        tx_dly    <= 2'b00;
		tx_finish_dly <= 3'b000;
	end 
	else begin
        tx_dly   <= tx_dly_next;
		tx_finish_dly <= tx_finish_dly_next;
	    in_data_reg <= in_data_reg;
		tx_data_byte <= tx_data_byte;
        tx_proc   <= 1'b0;
		tx_finish <= 1'b0;
		tx_done <= 1'b0;
    case (tx_state)
    TX_IDLE:
    begin
        if(tx_en & tx_start) begin
            in_data_reg <= in_data;
        end
    end

    TX_CRLF: 
    begin
	    tx_data_byte <= 8'h0D;
        tx_proc  <= 1'b1;
		led_reg[4] <= 1;
	end

    TX_CR_ACTIVE: 
    begin
		led_reg[1] <= 1;
		tx_finish <= ~bu_tx_busy;
	end
	
    TX_LF: 
    begin
	    tx_data_byte <= 8'h0A;
        tx_proc     <= 1'b1;
		led_reg[2]  <= 1;
	end
	
    TX_1st_BYTE: 
    begin
	    tx_data_byte[7:0] <= n2bcd;//nibble2BCD(in_data_reg[7:4]);
        tx_proc  <= 1'b1;
		led_reg[0] <= 1;
	end
    TX_1st_ACTIVE: 
    begin
 		led_reg[1] <= 1;
		tx_finish <= ~bu_tx_busy;
	end
	
    TX_2nd_BYTE:
    begin
	    tx_data_byte[7:0] <= n2bcd;//nibble2BCD(in_data_reg[3:0]);
        tx_proc  <= 1'b1;
		led_reg[2] <= 1;
	end
	
    TX_ASCII: 
    begin
	    tx_data_byte <= in_data_reg;
        tx_proc  <= 1'b1;
		led_reg[0] <= 1;
	end
	
	TX_ACTIVE:
    begin
		tx_finish <= ~bu_tx_busy;
		led_reg[3] <= 1;
	end
	TX_DONE:
	    tx_done <= 1;
    endcase
	end
end

// next state
always @ *
begin
    tx_state_next = 2'bxx;
    case (tx_state)
    TX_IDLE:  if(tx_en & tx_start) begin
	              case({tx_CRLF, tx_BCD})
                  2'b00: tx_state_next = TX_ASCII;
                  2'b01: tx_state_next = TX_1st_BYTE;
                  2'b10: tx_state_next = TX_CRLF;
                  2'b11: tx_state_next = TX_LF;
                  endcase
              end
			  else tx_state_next = tx_state;
    TX_CRLF:  if(tx_strob)
                  tx_state_next = TX_CR_ACTIVE;
			  else tx_state_next = tx_state;
    TX_CR_ACTIVE: 
              if(tx_finish_dly2clk) 
                  tx_state_next =  TX_LF;
			  else 
                  tx_state_next = tx_state;
	
    TX_LF:    if(tx_strob)
                  tx_state_next = TX_ACTIVE;
			  else tx_state_next = tx_state;
    TX_1st_BYTE:
              if(tx_strob)
                  tx_state_next = TX_1st_ACTIVE;
			  else tx_state_next = tx_state;
	TX_1st_ACTIVE:
              if(tx_finish_dly2clk) 
                  tx_state_next =  TX_2nd_BYTE;
			  else 	
                  tx_state_next = tx_state;
    TX_2nd_BYTE:
              if(tx_strob)
                  tx_state_next = TX_ACTIVE;
			  else tx_state_next = tx_state;
	TX_ASCII:
              if(tx_strob)
                  tx_state_next = TX_ACTIVE;
			  else tx_state_next = tx_state;
    TX_ACTIVE:if(tx_finish_dly2clk) 
                  tx_state_next =  TX_DONE;
			  else 
                  tx_state_next = tx_state;
    TX_DONE:  tx_state_next =  TX_IDLE;			  
    default:  tx_state_next =  tx_state;
    endcase
end

// sequential -- latch in the next state
always @ (posedge clk) begin
    if(rst) begin
        tx_state <= TX_IDLE;
	end
	else begin
        tx_state <= tx_state_next;
	end
end

endmodule

