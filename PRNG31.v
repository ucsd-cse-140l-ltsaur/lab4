module prng31 (
    input   clk,
    input   CE,
    input   load_seed,
    input   [30:0] seed,
    output  [30:0] o_prng31
);

reg [30:0] prng_lfsr;
wire       new_bit0 = prng_lfsr[2] ^ prng_lfsr[5] ^ prng_lfsr[6] 
                                   ^ prng_lfsr[12] ^ prng_lfsr[30];

//----------- output -----------------------------------
assign o_prng31[30:0] = prng_lfsr[30:0];


always @ (posedge clk) begin
    if(CE)begin
        if(load_seed) begin
           prng_lfsr[30:0] <=  seed[30:0]; 
        end
        else begin
           prng_lfsr[30:0] <= {prng_lfsr[30:1], new_bit0};
        end
	end
    else prng_lfsr <= prng_lfsr;
end

endmodule