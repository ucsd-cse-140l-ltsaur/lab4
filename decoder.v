module decoder (
    input        clk,
    input        rst,
    input        cont,      // 0: one i_rdy pluse has 1 byte from i_data
                            // 1: one i_idy pulse (n clks) has n bytes from i_data	
    input        load_seed,	// 1: 4 bytes from i_data are used as the seed of prng31
    input        start_dec, // 1: byte(s) from i_data is(are) used as input to deccoder
    input  [7:0] i_data,
    input        i_rdy,
	
    output [7:0] o_data,
    output       o_rdy,    // cont = 0 --> 1 byte from o_data per strob
                          // cont = 1 --> n bytes from o_data per strob 	
						  
    input  [7:0] stat_sel,
    output [7:0] stat_cnt,
	output [30:0] rand_seed
);

localparam LOAD_SEED0 = 3'b000, LOAD_SEED1 = 3'b001, 
           LOAD_SEED2 = 3'b010, LOAD_SEED3 = 3'b011, LOAD_SEED_END  = 3'b100,
           DEC_IDLE   = 3'b101, DEC_PROC   = 3'b110, DEC_DONE       = 3'b111; 
		  
//--------------- statistics ---------------------------------
parameter BYTE_COUNT_WIDTH = 11; 
parameter COUNT_WIDTH = 5; 

//--------------- deccoder FSM ---------------------------------
reg [2:0] dec_main_fsm;
reg [2:0] next_dec_main_fsm;


//--------------- internal to PRNG31 --------------------------
reg [7:0]  i_data_reg;
reg [31:0] rand_seed;
reg        rdy_tmp;

wire dec_data_rdy = (dec_load_seed)|(i_data_rdy & start_dec & ~load_seed);
wire [30:0] rand_num;
wire        rand_rdy;

wire dec_load_seed = ~|(dec_main_fsm ^ LOAD_SEED_END);
wire i_data_rdy = (cont)? i_rdy : (i_rdy & ~rdy_tmp);

//--------------- output ---------------------------------------
assign o_data[7:0] = i_data_reg[7:0] ^ rand_num[7:0]   ^ rand_num[15:8] 
                                     ^ rand_num[23:16] ^ rand_num[30:23];
reg [7:0] stat_cnt_reg;
assign stat_cnt = stat_cnt_reg;
					 
//synchronous input logic
always @ (posedge clk) begin : DEC_SYNC_INPUT_LOGIC
    if(rst) begin
        rdy_tmp <= 0;
    end
    else 
    begin
        //for detecting the rising edge of strob
        rdy_tmp <= i_rdy;		
    end		
end

prng31 dec_uu0 (
    .clk(clk),
    .CE(dec_data_rdy),
    .load_seed(dec_load_seed),
    .seed(rand_seed[30:0]),
    .o_prng31(rand_num[30:0])
//	.o_rdy(rand_rdy)
);

//sequencital logic of FSM
always @ (posedge clk) begin : DEC_FSM_SEQ_LOGIC
    if(rst) begin
        dec_main_fsm <= DEC_IDLE;
    end
    else begin		
        dec_main_fsm <= next_dec_main_fsm;
    end
end

always @ (dec_main_fsm or load_seed or start_dec or i_data_rdy) 
begin : DEC_FSM_COMB_LOGIC
    next_dec_main_fsm = 'bx;
    case (dec_main_fsm)
        DEC_IDLE: begin
            next_dec_main_fsm = (load_seed)?  LOAD_SEED0 :
                                (start_dec)?  DEC_PROC   : 
                                              DEC_IDLE;
        end
        DEC_PROC: begin
            next_dec_main_fsm = (i_data_rdy)? DEC_PROC: 
                                              DEC_DONE;           
        end
        DEC_DONE: begin
            next_dec_main_fsm = DEC_IDLE;
        end
        LOAD_SEED0: begin
            next_dec_main_fsm = (i_data_rdy)? LOAD_SEED1: LOAD_SEED0; 
        end
        LOAD_SEED1: begin
            next_dec_main_fsm = (i_data_rdy)? LOAD_SEED2: LOAD_SEED1; 
        end
        LOAD_SEED2: begin
            next_dec_main_fsm = (i_data_rdy)? LOAD_SEED3: LOAD_SEED2; 
        end
        LOAD_SEED3: begin
            next_dec_main_fsm = (i_data_rdy)? LOAD_SEED_END: LOAD_SEED3; 
        end
        LOAD_SEED_END: begin
            next_dec_main_fsm = DEC_IDLE;
        end
        default: begin
            next_dec_main_fsm = DEC_IDLE;
        end
    endcase
end


//synchronous output logic to prng31 module
always @ (posedge clk) begin : DEC_SYNC_OUTPUT_LOGIC
    //if(rst) begin
    //end
    //else 
    begin
        //latch in input data, which is directly used to generate 
		//decoded output, or is concatinated 4 bytes for load_seed (31 bits) 
        i_data_reg <= (i_data_rdy)? i_data : i_data_reg; 
		
        case (dec_main_fsm)
        LOAD_SEED0: begin
            rand_seed[30:24] <= i_data_reg[6:0];
        end
        LOAD_SEED1: begin
            rand_seed[23:16] <= i_data_reg[7:0];
        end
        LOAD_SEED2: begin
            rand_seed[15:8] <= i_data_reg[7:0];
        end
        LOAD_SEED3: begin
            rand_seed[7:0]  <= i_data_reg[7:0];
        end
        default: begin
            rand_seed <= rand_seed;
        end
		endcase
     end
end


//---------------------------------------------------------
//calculate # of 1 bits - # of 0 bits
reg [COUNT_WIDTH-1:0] stat_b0_count;
reg [COUNT_WIDTH-1:0] stat_b1_count;
reg [COUNT_WIDTH-1:0] stat_b2_count;
reg [COUNT_WIDTH-1:0] stat_b3_count;
reg [COUNT_WIDTH-1:0] stat_b4_count;
reg [COUNT_WIDTH-1:0] stat_b5_count;
reg [COUNT_WIDTH-1:0] stat_b6_count;
reg [COUNT_WIDTH-1:0] stat_b7_count;

wire [COUNT_WIDTH-1:0] stat_b0_count_next;
defparam u_stat_b0_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b0_count(
.result (stat_b0_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b0_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[0])
);

wire [COUNT_WIDTH-1:0] stat_b1_count_next;
defparam u_stat_b1_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b1_count(
.result (stat_b1_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b1_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[1])
);

wire [COUNT_WIDTH-1:0] stat_b2_count_next;
defparam u_stat_b2_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b2_count(
.result (stat_b2_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b2_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[2])
);

wire [COUNT_WIDTH-1:0] stat_b3_count_next;
defparam u_stat_b3_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b3_count(
.result (stat_b3_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b3_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[3])
);

wire [COUNT_WIDTH-1:0] stat_b4_count_next;
defparam u_stat_b4_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b4_count(
.result (stat_b4_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b4_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[4])
);

wire [COUNT_WIDTH-1:0] stat_b5_count_next;
defparam u_stat_b5_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b5_count(
.result (stat_b5_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b5_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[5])
);

wire [COUNT_WIDTH-1:0] stat_b6_count_next;
defparam u_stat_b6_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b6_count(
.result (stat_b6_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b6_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[6])
);

wire [COUNT_WIDTH-1:0] stat_b7_count_next;
defparam u_stat_b7_count.N = COUNT_WIDTH;
N_bit_counter u_stat_b7_count(
.result (stat_b7_count_next[COUNT_WIDTH-1:0])  , // Output
.r1 (stat_b7_count[COUNT_WIDTH-1:0])        , // input
.up (o_data[7])
);

reg [BYTE_COUNT_WIDTH-1:0] byte_count;
wire [BYTE_COUNT_WIDTH-1:0] byte_count_next;
defparam u_byte_count.N = BYTE_COUNT_WIDTH;
N_bit_counter u_byte_count(
.result (byte_count_next[BYTE_COUNT_WIDTH-1:0])  , // Output
.r1 (byte_count[BYTE_COUNT_WIDTH-1:0])        , // input
.up (1'b1)
);


//STAT: output logic
always @ (posedge clk) begin : DEC_STAT_LOGIC
    if(rst) begin
        stat_b0_count <= 'h0;
        stat_b1_count <= 'h0;
        stat_b2_count <= 'h0;
        stat_b3_count <= 'h0;
        stat_b4_count <= 'h0;
        stat_b5_count <= 'h0;
        stat_b6_count <= 'h0;
        stat_b7_count <= 'h0;
        byte_count    <= 'h0;
    end
    else begin
        if(|(dec_main_fsm ^ DEC_DONE)) begin
        stat_b0_count <= stat_b0_count;
        stat_b1_count <= stat_b1_count;
        stat_b2_count <= stat_b2_count;
        stat_b3_count <= stat_b3_count;
        stat_b4_count <= stat_b4_count;
        stat_b5_count <= stat_b5_count;
        stat_b6_count <= stat_b6_count;
        stat_b7_count <= stat_b7_count;
        byte_count    <= byte_count;
        end 
		else begin
        stat_b0_count <= stat_b0_count_next;
        stat_b1_count <= stat_b1_count_next;
        stat_b2_count <= stat_b2_count_next;
        stat_b3_count <= stat_b3_count_next;
        stat_b4_count <= stat_b4_count_next;
        stat_b5_count <= stat_b5_count_next;
        stat_b6_count <= stat_b6_count_next;
        stat_b7_count <= stat_b7_count_next;
        byte_count    <= byte_count_next;
		end
		
        case (stat_sel)
		8'h00: stat_cnt_reg <= stat_b0_count;
		8'h01: stat_cnt_reg <= stat_b1_count;
		8'h02: stat_cnt_reg <= stat_b2_count;
		8'h03: stat_cnt_reg <= stat_b3_count;
		8'h05: stat_cnt_reg <= stat_b4_count;
		8'h06: stat_cnt_reg <= stat_b5_count;
		8'h07: stat_cnt_reg <= stat_b6_count;
		8'h08: stat_cnt_reg <= stat_b7_count;
		8'h09: stat_cnt_reg[7:0] <= byte_count[7:0];
		8'h0a: stat_cnt_reg <= byte_count[BYTE_COUNT_WIDTH-1:8];
		default: stat_cnt_reg <= 0;
		endcase
    end
end
//-------------------------------------------------------------

endmodule
