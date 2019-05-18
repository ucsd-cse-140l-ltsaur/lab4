//--------------------------
module Loopback (
input  wire       clk,
input  wire       rst,
input  wire       loopback,
input  wire       bu_rx_data_rdy,
input  wire [7:0] bu_rx_data,
input  wire       bu_tx_busy,

output wire [7:0] bu_tx_data,
output wire       bu_tx_data_rdy,
output reg        bu_tx_done,
output reg  [4:0] lb_led
);
//---------- MUX control echo or tx ----------
assign bu_tx_data = (loopback)? bu_rx_data:8'bz;
assign bu_tx_data_rdy = (loopback)? bu_rx_data_rdy:1'bz;
//assign bu_tx_done = ~|(bu_tx_bus_fsm ^ BU_TX_BUS_DONE);

//-----------  bu_tx_data bus FSM --------------------
localparam BU_TX_BUS_IDLE = 2'b00, BU_TX_BUS_ACTIVE = 2'b01, BU_TX_BUS_DONE = 2'b10;
reg  [1:0] bu_tx_bus_fsm;
reg  [1:0] bu_tx_bus_fsm_next;
always @ (posedge clk or posedge rst) begin
    if(rst) begin
	    bu_tx_bus_fsm <= BU_TX_BUS_IDLE;
	end
	else begin
	    bu_tx_bus_fsm <= bu_tx_bus_fsm_next;
	end
end


always @ *
begin
    if(rst) lb_led = 5'h00;
	
    bu_tx_bus_fsm_next = 2'bxx;
	lb_led[4] = bu_tx_done;
	case (bu_tx_bus_fsm)
	BU_TX_BUS_IDLE:
	    bu_tx_bus_fsm_next = (bu_tx_data_rdy)? BU_TX_BUS_ACTIVE : BU_TX_BUS_IDLE;
	BU_TX_BUS_ACTIVE:
	begin
	    bu_tx_done = 1'b0;
	    bu_tx_bus_fsm_next = (bu_tx_busy)? BU_TX_BUS_ACTIVE : BU_TX_BUS_DONE;
		lb_led[3] = 1'b1;
	end
	BU_TX_BUS_DONE:
	begin
	    bu_tx_done = 1'b1;
	    bu_tx_bus_fsm_next = BU_TX_BUS_IDLE;
	end
	endcase
end

endmodule