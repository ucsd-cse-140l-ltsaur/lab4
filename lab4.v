module  lab4 (
input             clk,
input             rst,
input  wire       bu_rx_data_rdy,
input  wire [7:0] bu_rx_data,
input  wire       bu_tx_busy,

output wire [7:0] bu_tx_data,
output wire       bu_tx_data_rdy,
output wire [4:0] led
);

//------ for debugging ----------------
reg[4:0] led_reg;
reg[1:0]     led_select;

assign led[4:0] = (led_select == 2'b00)? parser_fsm[4:0]: 
                  (led_select == 2'b01)? led_Tx8Bits[4:0] :
                  (led_select == 2'b10)? lb_led[4:0]:
                   led_reg[4:0] ; 

//--------------------- RX: Latch input --------------------------
reg [1:0] l_bu_rx_data_rdy;
reg [7:0] l_bu_rx_data;
wire in_data_rdy = l_bu_rx_data_rdy[0] & ~l_bu_rx_data_rdy[1];
wire [7:0] bu_rx_data_next = (bu_rx_data_rdy)? bu_rx_data: l_bu_rx_data;
wire [1:0] bu_rx_data_rdy_next = {l_bu_rx_data_rdy[0], bu_rx_data_rdy};

always @ (posedge clk or posedge rst) begin
    if(rst) begin
        l_bu_rx_data_rdy <= 2'b00;
    end
    else begin
        l_bu_rx_data_rdy <= bu_rx_data_rdy_next;
        l_bu_rx_data <= bu_rx_data_next;
    end
end

//------------------------------------------------------
localparam PARSER_IDLE = 5'h00, PARSER_ERR = 5'h1F,
           PARSER_CR    = 5'h01,  
           PARSER_LF    = 5'h02, 
           PARSER_CRLF = 5'h03,  
           
           PARSER_E0 = 5'h06, PARSER_E1 = 5'h07, PARSER_E2 = 5'h08,//E: msg
           PARSER_D0 = 5'h09, PARSER_D1 = 5'h0A, PARSER_D2 = 5'h0B,//D: msg
           PARSER_L0 = 5'h0C, PARSER_L1 = 5'h0D, PARSER_L2 = 5'h0E, PARSER_L3 = 5'h0F, //load seed
           PARSER_R0 = 5'h10, PARSER_R1 = 5'h11, PARSER_R2 = 5'h12,//output PRNG
           PARSER_R3 = 5'h13, PARSER_R4 = 5'h14, PARSER_R5 = 5'h15,//output PRNG
           PARSER_S0 = 5'h16, PARSER_S1 = 5'h17, PARSER_S2 = 5'h18,//output stat cnts
           PARSER_S3 = 5'h19, PARSER_S4 = 5'h1A, PARSER_S5 = 5'h1B,//output stat cnts
           PARSER_S6 = 5'h1C, PARSER_S7 = 5'h1D, PARSER_S8 = 5'h1E;//output stat cnts


//-------- FSM signals --------------
reg  [4:0] parser_fsm;  
reg  [4:0] parser_fsm_next;
reg read_bcd, read_cr, read_somethingelse;    

//-----------  FSM Sequential logics -------------
always @ (posedge clk) begin
    if(rst) begin
        parser_fsm <= PARSER_IDLE;
	end 
	else begin
        parser_fsm <= parser_fsm_next;
	end
end

//------ combo logics -----------------
//----------------------- local functions --------------------------------
// E: plain msg
function   get_E;
input wire       l_rx_data_rdy;
input wire [7:0] l_rx_data;
    get_E = l_rx_data_rdy & 
            (~|(l_rx_data ^ "E") | ~|(l_rx_data ^ "e"));
endfunction

// D: encripted digits
function get_D;
input wire       l_rx_data_rdy;
input wire [7:0] l_rx_data;
    get_D = l_rx_data_rdy & 
            (~|(l_rx_data ^ "D") | ~|(l_rx_data ^ "d"));
endfunction

// L: 01 ... FF (CR), in BCD format
function get_L;
input wire       l_rx_data_rdy;
input wire [7:0] l_rx_data;
    get_L = l_rx_data_rdy & 
            (~|(l_rx_data ^ "L") | ~|(l_rx_data ^ "l")) ;
endfunction

// R: peek pseudo random numbers
function get_R;
input wire       l_rx_data_rdy;
input wire [7:0] l_rx_data;
    get_R = l_rx_data_rdy & 
            (~|(l_rx_data ^ "R") | ~|(l_rx_data ^ "r"));
endfunction

// S: peek enc, dec stat cnts
function get_S;
input wire       l_rx_data_rdy;
input wire [7:0] l_rx_data;
    get_S = l_rx_data_rdy & 
            (~|(l_rx_data ^ "S") | ~|(l_rx_data ^ "s"));
endfunction

// get :
function get_col;
input wire       l_rx_data_rdy;
input wire [7:0] l_rx_data;
    get_col = l_rx_data_rdy & (~|(l_rx_data ^ ":"));
endfunction

// get CR -- end of typing msg in BCD format
function get_CR;
input wire       l_rx_data_rdy;
input wire [7:0] l_rx_data;
    get_CR = l_rx_data_rdy & (~|(l_rx_data ^ 8'h0d));
endfunction

function get_BCD;
input wire       l_rx_data_rdy;
input wire [7:0] l_byte;

reg is_BCD;
begin
/*
is_BCD = (~|(l_byte ^ 8'h30)) | (~|(l_byte ^ 8'h31)) | (~|(l_byte ^ 8'h32)) |
         (~|(l_byte ^ 8'h33)) | (~|(l_byte ^ 8'h34)) | (~|(l_byte ^ 8'h35)) |
         (~|(l_byte ^ 8'h36)) | (~|(l_byte ^ 8'h37)) | (~|(l_byte ^ 8'h38)) |
         (~|(l_byte ^ 8'h39)) | (~|(l_byte ^ 8'h41)) | (~|(l_byte ^ 8'h42)) |
         (~|(l_byte ^ 8'h43)) | (~|(l_byte ^ 8'h44)) | (~|(l_byte ^ 8'h45)) |
         (~|(l_byte ^ 8'h46)) | (~|(l_byte ^ 8'h61)) | (~|(l_byte ^ 8'h62)) |
         (~|(l_byte ^ 8'h63)) | (~|(l_byte ^ 8'h64)) | (~|(l_byte ^ 8'h65)) |
         (~|(l_byte ^ 8'h66));
*/

is_BCD = ( ~|(l_byte[7:3] ^ 5'b00110))   |  //0-7
         ( ~|(l_byte[7:1] ^ 7'b0011100)) |  //8, 9
         (~|({l_byte[7:6], l_byte[4:3]} ^ 4'b0100) & 
		   |(l_byte[2:0] ^ 3'b000) & |(l_byte[2:0] ^ 3'b111)); //Aa~Ff

get_BCD = is_BCD & l_rx_data_rdy;

end
endfunction

function [3:0] BCD2nibble;
input [7:0] i_byte;

    BCD2nibble = (i_byte[6])?
      {1'b0, (i_byte[2] | &i_byte[1:0]), ^i_byte[1:0], ~i_byte[0]} :
      i_byte[3:0];
endfunction
//----------------------- end of functions ----------------------------------
//----------------------- combo always @ *, next state ----------------------
wire col_rdy   = get_col(in_data_rdy, l_bu_rx_data);
wire bcd_rdy   = get_BCD(in_data_rdy, l_bu_rx_data);
wire cr_rdy    = get_CR(in_data_rdy, l_bu_rx_data);
wire e_rdy     = get_E(in_data_rdy, l_bu_rx_data);
wire d_rdy     = get_D(in_data_rdy, l_bu_rx_data);
wire l_rdy     = get_L(in_data_rdy, l_bu_rx_data);
wire peek_seed = get_R(in_data_rdy, l_bu_rx_data);
wire peek_stat = get_S(in_data_rdy, l_bu_rx_data);
wire [3:0] bcd_data = BCD2nibble(l_bu_rx_data);
wire encfifoempty = ~enc_fifo_emptyB; 
wire decfifoempty = ~dec_fifo_emptyB;


always @ * //(parser_fsm or l_bu_rx_data or in_data_rdy)
begin
    parser_fsm_next = 5'bxxxxx;

    case (parser_fsm)
        PARSER_IDLE:begin 
                    parser_fsm_next = 
                     (e_rdy)? PARSER_E0 :
                     (l_rdy)? PARSER_L0 :
                     (d_rdy)? PARSER_D0 :
                     (peek_seed)? PARSER_R0 :
                     (peek_stat)? PARSER_S0 : PARSER_IDLE ;
					end 
        PARSER_CR:  if(lb_tx_done)  //wait for CR be looped back to term
                        parser_fsm_next = PARSER_LF;
                    else 
                        parser_fsm_next = PARSER_CR;
		PARSER_LF:  if(tx_8bits_done) //LF0 tx out LF
                        parser_fsm_next = PARSER_IDLE;
                    else 
                        parser_fsm_next = PARSER_LF;
		PARSER_CRLF:                                     //CRLF0 tx out CR
                    if(tx_8bits_done)
                        parser_fsm_next = PARSER_IDLE;
                    else
                        parser_fsm_next = PARSER_CRLF;
					
        PARSER_ERR: parser_fsm_next = PARSER_ERR;
		
        PARSER_E0:  case ({col_rdy, in_data_rdy})
                    {1'b1, 1'b1}: parser_fsm_next = PARSER_E1;
                    {1'b0, 1'b1}: parser_fsm_next = PARSER_ERR;
                    default: parser_fsm_next = PARSER_E0;
					endcase
                    
        PARSER_E1:  if(read_cr) parser_fsm_next = PARSER_E2;
                    else if(read_somethingelse) parser_fsm_next = PARSER_ERR;
                    else parser_fsm_next = PARSER_E1;
                    
        PARSER_E2:  if(encfifoempty) parser_fsm_next = PARSER_IDLE;
                    else parser_fsm_next = PARSER_E2;

        PARSER_D0:  case ({col_rdy, in_data_rdy})
                    {1'b1, 1'b1}: parser_fsm_next = PARSER_D1;
                    {1'b0, 1'b1}: parser_fsm_next = PARSER_ERR;
                    default: parser_fsm_next = PARSER_D0;
					endcase
					
        PARSER_D1:  if(read_cr) parser_fsm_next = PARSER_D2;
                    else if(read_somethingelse) parser_fsm_next = PARSER_ERR;
                    else parser_fsm_next = PARSER_D1;

        PARSER_D2:  if(decfifoempty) parser_fsm_next = PARSER_IDLE;
                    else parser_fsm_next = PARSER_D2;
						
        PARSER_L0:  case ({col_rdy, in_data_rdy})
                    {1'b1, 1'b1}: parser_fsm_next = PARSER_L1;
                    {1'b0, 1'b1}: parser_fsm_next = PARSER_ERR;
                    default: parser_fsm_next = PARSER_L0;
					endcase
					
        PARSER_L1:  if(read_bcd) begin
                        parser_fsm_next = PARSER_L2;
                    end else
                    if(read_cr) begin
                        parser_fsm_next = PARSER_L3;
                    end else
                    if(read_somethingelse) begin
                        parser_fsm_next = PARSER_ERR;
                    end
                    else begin 
                        parser_fsm_next = PARSER_L1;
                    end
					
        PARSER_L2:  if(read_bcd) begin
                        parser_fsm_next = PARSER_L1;
                    end else 
                    if(read_cr) begin
					    parser_fsm_next = PARSER_L3;
                    end else
                    if (read_somethingelse) begin
					    parser_fsm_next = PARSER_ERR;
                    end
                    else parser_fsm_next = PARSER_L2;
 									 
        PARSER_L3:  parser_fsm_next = (|(in_cnt ^ out_cnt))?PARSER_L3:PARSER_CR;
		
                    						
		PARSER_R0:  case ({col_rdy, in_data_rdy})
                    {1'b1, 1'b1}: parser_fsm_next = PARSER_R1;
                    {1'b0, 1'b1}: parser_fsm_next = PARSER_ERR;
                    default: parser_fsm_next = PARSER_R0;
					endcase

        PARSER_R1:  if(lb_tx_done)                    
                        parser_fsm_next = PARSER_R2; 
                    else parser_fsm_next = PARSER_R1;

        PARSER_R2:  if(tx_8bits_done)                    //1st 8bit
                         parser_fsm_next = PARSER_R3;
                    else parser_fsm_next = PARSER_R2;
					
        PARSER_R3:  if(tx_8bits_done)                    //2nd 8bit
                         parser_fsm_next = PARSER_R4;
                    else parser_fsm_next = PARSER_R3;
					
        PARSER_R4:  if(tx_8bits_done)                    //3rd 8bit
                         parser_fsm_next = PARSER_R5;
                    else parser_fsm_next = PARSER_R4;
        PARSER_R5:  if(tx_8bits_done)                    //4th 8bit
                         parser_fsm_next = PARSER_CRLF;
                    else parser_fsm_next = PARSER_R5;
						
        PARSER_S0:  case ({col_rdy, in_data_rdy})
                    {1'b1, 1'b1}: parser_fsm_next = PARSER_S1;
                    {1'b0, 1'b1}: parser_fsm_next = PARSER_ERR;
                    default: parser_fsm_next = PARSER_S0;
					endcase
						
        PARSER_S1:  case ({bcd_rdy, in_data_rdy})
                    {1'b1, 1'b1}: parser_fsm_next = PARSER_S2;
                    {1'b0, 1'b1}: parser_fsm_next = PARSER_ERR;
                    default: parser_fsm_next = PARSER_S1;
					endcase

        PARSER_S2:  case ({cr_rdy, in_data_rdy})
                    {1'b1, 1'b1}: parser_fsm_next = PARSER_IDLE;
                    {1'b0, 1'b1}: parser_fsm_next = PARSER_ERR;
                    default: parser_fsm_next = PARSER_S2;
					endcase

        default : parser_fsm_next = parser_fsm;
    endcase
end



//------------------ FSM Output -----------------------------------------
reg  [31:0]prng31_seed;
reg  [1:0] in_cnt, out_cnt;
//used in load seeds
wire [7:0] seed_out = (out_cnt==0)? prng31_seed[7:0]:
                      (out_cnt==1)? prng31_seed[15:8]:
                      (out_cnt==2)? prng31_seed[23:16]:
                                    prng31_seed[31:24];
wire [1:0] in_cnt_wire = in_cnt;
wire [1:0] out_cnt_wire = out_cnt;
wire [1:0] in_cnt_next, out_cnt_next;
defparam load_seedU0.N = 2; 
N_bit_counter load_seedU0(
.result(in_cnt_next)      , // Output
.r1(in_cnt_wire)          , // input
.up(1'b1)
);

defparam load_seedU1.N = 2; 
N_bit_counter load_seedU1(
.result(out_cnt_next)      , // Output
.r1(out_cnt_wire)          , // input
.up(1'b1)
);

//---------------------------- Echo, Loopback -----------------------
reg loopback_enable;
wire lb_tx_done;
wire [4:0] lb_led;
Loopback lab4lpbk(
        .clk(clk),
		.rst(rst),
        .loopback(loopback_enable),
		
        .bu_rx_data_rdy(in_data_rdy),
        .bu_rx_data(l_bu_rx_data),
        .bu_tx_busy(bu_tx_busy),

        .bu_tx_data(bu_tx_data),
        .bu_tx_data_rdy(bu_tx_data_rdy),
        .bu_tx_done(lb_tx_done),
		.lb_led(lb_led)
);

parameter SEED0 = 3'h0, SEED1 = 3'h1, SEED2 = 3'h2, SEED3 = 3'h3,
          ENC_O = 3'h4, DEC_O = 3'h5;

reg  [2:0] src_of_input;
reg  [7:0] l_tx_data_reg;
wire [7:0] l_tx_data = l_tx_data_reg;

always @*
begin
    case(src_of_input) 
    SEED0: l_tx_data_reg = prng31_seed[7:0];
    SEED1: l_tx_data_reg = prng31_seed[15:8];
    SEED2: l_tx_data_reg = prng31_seed[23:16];
    SEED3: l_tx_data_reg = prng31_seed[31:24];
    ENC_O: l_tx_data_reg = enc_out_data;
	DEC_O: l_tx_data_reg = dec_out_data;
    endcase
end

reg        tx_en;
reg        tx_crlf;
reg        tx_BCD;
reg        tx_once;
reg  [1:0] tx_start;
wire [1:0] tx_start_next = {tx_start[0], tx_once};
wire       tx_start_strob = tx_start[0] & ~tx_start[1];
wire       tx_8bits_done;
wire [4:0] led_Tx8Bits;

Tx8Bits lab4tx8bits(
.clk(clk),
.rst(rst),

// input data
.tx_en(tx_en),
.tx_start(tx_start_strob),
.tx_CRLF(tx_crlf),
.tx_BCD(tx_BCD),
.in_data(l_tx_data),
.bu_tx_busy(bu_tx_busy),

// output data
.bu_tx_data(bu_tx_data),
.bu_tx_data_rdy(bu_tx_data_rdy),
.tx_done(tx_8bits_done)
,.led(led_Tx8Bits)
);

//------------------------ Encoder FIFO ---------------------------------
reg        flo_enc_fifo;
wire       flo_enc_fifo_w = flo_enc_fifo;
wire [7:0] enc_out_data, enc2fifo_data;
wire       enc_data_rdy, enc2fifo_data_rdy;
wire       enc_fifo_emptyB;

uartTxBuf lab4encfifo(
.emptyB(enc_fifo_emptyB),
.utb_txdata(enc_out_data),
.utb_txdata_rdy(enc_data_rdy),

.txdata(enc2fifo_data),          // tx data to fifo
.txDataValid(enc2fifo_data_rdy), // tx data is valid
.txBusy(flo_enc_fifo_w),         // tx uart is busy

.reset(rst),
.clk(clk)
);
//----------------------------- Encoder --------------------------------
reg load_seed, start_enc;
wire [7:0] enc_stat_cnt;
wire load_seed_w = load_seed;
wire [7:0] i_enc_data = (load_seed_w) ? seed_out : l_bu_rx_data;
wire       i_enc_data_rdy = (load_seed_w)? ~|(parser_fsm ^ PARSER_L3):
                                         in_data_rdy;

encoder lab4enc(
.clk(clk),
.rst(rst),
.cont(1'b1),            // 0: one i_rdy pluse has 1 byte from i_data
                        // 1: one i_idy pulse (n clks) has n bytes from i_data	
.load_seed(load_seed_w),// 1: 4 bytes from i_data are used as the seed of prng31
.start_enc(start_enc),  // 1: byte(s) from i_data is(are) used as input to encoder
.i_data(i_enc_data),
.i_rdy(i_enc_data_rdy),

.o_data(enc2fifo_data),
.o_rdy(enc2fifo_data_rdy),     // cont = 0 --> 1 byte from o_data per strob
                               // cont = 1 --> n bytes from o_data per strob 	

.stat_sel(l_bu_rx_data),
.stat_cnt(enc_stat_cnt)
);

//------------- Decoder Output FIFO --------------------------
reg        flo_dec_fifo;
wire       flo_dec_fifo_w = flo_dec_fifo;
wire [7:0] dec_out_data, dec2fifo_data;
wire       dec_data_rdy, dec2fifo_data_rdy;
wire       dec_fifo_emptyB;

uartTxBuf lab4decfifo(
.emptyB(dec_fifo_emptyB),
.utb_txdata(dec_out_data),
.utb_txdata_rdy(dec_data_rdy),

.txdata(dec2fifo_data),          // tx data to fifo
.txDataValid(dec2fifo_data_rdy), // tx data is valid
.txBusy(flo_dec_fifo_w),         // tx uart is busy

.reset(rst),
.clk(clk)
);

//------------------------- Decoder ----------------------------------------
reg start_dec, user_input;
wire [7:0] dec_stat_cnt;
wire [7:0] i_dec_data = (load_seed_w) ? prng31_seed[out_cnt]: 
                        (user_input)? l_bu_rx_data : enc_out_data;
wire       i_dec_data_rdy = (load_seed_w)? ~|(parser_fsm ^ PARSER_L3):
                            (user_input)? in_data_rdy: enc_data_rdy;

decoder lab4dec(
.clk(clk),
.rst(rst),
.cont(1'b1),            // 0: one i_rdy pluse has 1 byte from i_data
                        // 1: one i_idy pulse (n clks) has n bytes from i_data	
.load_seed(load_seed_w),// 1: 4 bytes from i_data are used as the seed of prng31
.start_dec(start_dec),  // 1: byte(s) from i_data is(are) used as input to encoder
.i_data(i_dec_data),
.i_rdy(i_dec_data_rdy),

.o_data(dec2fifo_data),
.o_rdy(dec2fifo_data_rdy),     // cont = 0 --> 1 byte from o_data per strob
                          // cont = 1 --> n bytes from o_data per strob 	

.stat_sel(l_bu_rx_data),
.stat_cnt(dec_stat_cnt)
);
//--------------------------------------------------------------------------------------
reg  l_temp;

// actions: set control signals
always @ (posedge clk) begin
    if(rst) begin
	led_select  <= 2'b00;
	led_reg[4:0]<=5'b00000;
    end
    else begin
		        loopback_enable <= 1;
                tx_en           <= 0;
                tx_start     <= tx_start_next;
                tx_crlf   <= 0;
                tx_BCD    <= 0;
                tx_once   <= 0;

                load_seed    <= 0; 
		        flo_enc_fifo <= 1; //flow off enc fifo
                start_enc    <= 0;
                start_dec    <= 0;
                flo_dec_fifo <= 1; //flow off dec fifo
                user_input   <= 0;
		        in_cnt <= 2'h0;
	            out_cnt <= 2'h0;

                //-- used to determine FSM's next state
		        read_bcd <= 0;
		        read_cr  <= 0;
		        read_somethingelse <= 0;
		
		        //-- random number seed
		        prng31_seed[2'b00] <= prng31_seed[2'b00];
		        prng31_seed[2'b01] <= prng31_seed[2'b01];
		        prng31_seed[2'b10] <= prng31_seed[2'b10];
		        prng31_seed[2'b11] <= prng31_seed[2'b11];
		
        case (parser_fsm)
        PARSER_IDLE : 
            begin
			led_select <= (get_col)? 2'b01:
			              (get_BCD)? 2'b10:
			              (get_CR) ? 2'b11:led_select;			
            end
        PARSER_CRLF: 
            begin
                //tx_start        <= tx_start_next;
                tx_crlf         <= 1; //
                tx_BCD          <= 0; //(tx_crlf, tx_BCD)=(1, 0):tx CR first then LF
                tx_once         <= ~tx_8bits_done;
 		        loopback_enable <= 0;
			    tx_en           <= 1;
		    end
					
        PARSER_LF: 
            begin
                //tx_start        <= tx_start_next;
                tx_crlf         <= 1; //
                tx_BCD          <= 1; //(tx_crlf, tx_BCD)=(1, 1):tx LF only
                tx_once         <= ~tx_8bits_done;
 		        loopback_enable <= 0;
			    tx_en           <= 1;
		    end
         //PARSER_E0:  
        PARSER_E1: begin
                       loopback_enable <= ~cr_rdy;
                       read_bcd  <= bcd_rdy;
				       read_cr   <= cr_rdy;
                       start_enc <= bcd_rdy;
                       read_somethingelse <= ~bcd_rdy & ~cr_rdy & in_data_rdy;
                   end
        PARSER_E2: begin
                       flo_enc_fifo <= 0;
				   end
        //PARSER_D0:  
        PARSER_D1: begin
                       loopback_enable <= ~cr_rdy;
                       read_bcd  <= bcd_rdy;
				       read_cr   <= cr_rdy;
                       start_dec <= bcd_rdy;
                       read_somethingelse <= ~bcd_rdy & ~cr_rdy & in_data_rdy;
                   end
        PARSER_D2: begin
                       flo_dec_fifo <= 0;
				   end
				   
        //PARSER_L0: 
        PARSER_L1: begin 
                   if(bcd_rdy) begin
                       case(in_cnt)
                       2'b11: prng31_seed[7:4]   <= bcd_data[3:0];
					   2'b10: prng31_seed[12:9]  <= bcd_data[3:0];
					   2'b01: prng31_seed[23:20] <= bcd_data[3:0];
					   2'b00: prng31_seed[31:28] <= bcd_data[3:0];
                       endcase
                   end	
                   read_bcd <= bcd_rdy;
				   read_cr  <= cr_rdy;
                   read_somethingelse <= ~bcd_rdy & ~cr_rdy & in_data_rdy;
				   end
        PARSER_L2: begin 
                   if(bcd_rdy) begin
                       in_cnt <= in_cnt_next;
                       case(in_cnt)
                       2'b11: prng31_seed[3:0]   <= bcd_data[3:0];
					   2'b10: prng31_seed[11:8]  <= bcd_data[3:0];
					   2'b01: prng31_seed[19:16] <= bcd_data[3:0];
					   2'b00: prng31_seed[27:24] <= bcd_data[3:0];
                       endcase
                   end
                   read_bcd <= bcd_rdy;
  				   read_cr <= cr_rdy;
                   read_somethingelse <= ~bcd_rdy & ~cr_rdy & in_data_rdy;               
				   end
        PARSER_L3: begin 
                       if(|(out_cnt ^ in_cnt)) begin
                           load_seed <= 1; 
                           start_enc <= 1;
                           start_dec <= 1;
                       end
                       out_cnt <= out_cnt_next;	                       
                   end
			
        PARSER_R2: begin  
 		            loopback_enable <= 0;
					tx_en           <= 1;
                    tx_crlf         <= 0;
                    tx_BCD          <= 1;
                    tx_once         <= ~tx_8bits_done;					   
                    src_of_input    <= SEED3;
					led_reg[1] <= 1;
		           end
        PARSER_R3: begin
 		               loopback_enable <= 0;
					   tx_en           <= 1;
                       tx_crlf         <= 0;
                       tx_BCD          <= 1;
                       tx_once         <= ~tx_8bits_done;
                       src_of_input    <= SEED2;
					led_reg[2] <= 1;
		           end
         PARSER_R4: begin
 		               loopback_enable <= 0;
					   tx_en           <= 1;
                       tx_crlf         <= 0;
                       tx_BCD          <= 1;
                       tx_once         <= ~tx_8bits_done;
                       src_of_input    <= SEED1;
					led_reg[3] <= 1;
		           end
         PARSER_R5: begin
 		               loopback_enable <= 0;
					   tx_en           <= 1;
                       tx_crlf         <= 0;
                       tx_BCD          <= 1;
                       tx_once         <= ~tx_8bits_done;
                       src_of_input    <= SEED0;
					led_reg[4] <= 1;
		           end
        //PARSER_S0:  
        PARSER_S1: begin
                       l_temp <= ~|(l_bu_rx_data ^ 8'h31);
                   end
        PARSER_S2: begin
                       user_input <= l_temp;
				   end
        endcase
    end
end

endmodule

