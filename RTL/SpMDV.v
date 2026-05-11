module SpMDV 
(
	input clk,
	input rst,

	// Input signals
	input start_init,
    input [7 : 0] raw_input,
    input raw_data_valid,
	input w_input_valid,

	// Output signals
    output reg raw_data_request,
	output reg ld_w_request,
	output reg [21 : 0] o_result,
	output reg o_valid
);

    //Counters
	reg [13:0] load_count; // weight/position: 0~12287, vector: 0~4095
    reg [8:0]  row_count; // 0~255
    reg [5:0]  nonzero_count; // 0~47
	reg [3:0]  vector_count; // 0~15

	//States
    localparam IDLE0         = 5'd0;
    localparam LOAD_WEIGHT   = 5'd1;
    localparam LOAD_POSITION = 5'd2;
    localparam LOAD_BIAS     = 5'd3;
    localparam IDLE1         = 5'd4;
    localparam LOAD_VECTOR   = 5'd5;

    localparam READ_BIAS     = 5'd6;
    localparam WAIT_BIAS     = 5'd7;
    localparam INIT_MULT     = 5'd8;

    localparam READ_WP       = 5'd9;
    localparam WAIT_WP       = 5'd10;
    localparam LATCH_WP      = 5'd11;
	
    localparam READ_VECTOR   = 5'd12;
    localparam WAIT_VECTOR   = 5'd13;
    localparam CALCULATION   = 5'd14;
    localparam OUTPUT        = 5'd15;

	localparam PRE_LOAD      = 5'd16;
	localparam WAIT_LOAD     = 5'd17;

	reg [4:0] state;
	reg [4:0] nextstate;


	// weight SRAM (*3 4096*8)
	reg  [11:0] w0_A, w1_A, w2_A;
	reg  [7:0]  w0_D, w1_D, w2_D;
	wire [7:0]  w0_Q, w1_Q, w2_Q;
	reg  w0_CEN, w1_CEN, w2_CEN;
	reg  w0_WEN, w1_WEN, w2_WEN;

	// position SRAM (*3 4096*8)
	reg  [11:0] p0_A, p1_A, p2_A;
	reg  [7:0]  p0_D, p1_D, p2_D;
	wire [7:0]  p0_Q, p1_Q, p2_Q;
	reg  p0_CEN, p1_CEN, p2_CEN;
	reg  p0_WEN, p1_WEN, p2_WEN;

	// bias SRAM (*1 256*8)
	reg  [7:0] b_A;
	reg  [7:0] b_D;
	wire [7:0] b_Q;
	reg  b_CEN;
	reg  b_WEN;

	// vector SRAM (*1 4096*8) 
	reg  [11:0] x_A;
	reg  [7:0]  x_D;
	wire [7:0]  x_Q;
	reg  x_CEN;
	reg  x_WEN;

	// SRAMs
	sram_4096x8 W_0 (.A(w0_A), .D(w0_D), .Q(w0_Q),
					.CLK(clk), .CEN(w0_CEN), .WEN(w0_WEN));
	sram_4096x8 W_1 (.A(w1_A), .D(w1_D), .Q(w1_Q), 
					.CLK(clk), .CEN(w1_CEN), .WEN(w1_WEN));
	sram_4096x8 W_2 (.A(w2_A), .D(w2_D), .Q(w2_Q), 
					.CLK(clk), .CEN(w2_CEN), .WEN(w2_WEN));

	sram_4096x8 P_0 (.A(p0_A), .D(p0_D), .Q(p0_Q),
					.CLK(clk), .CEN(p0_CEN), .WEN(p0_WEN));
	sram_4096x8 P_1 (.A(p1_A), .D(p1_D), .Q(p1_Q), 
					.CLK(clk), .CEN(p1_CEN), .WEN(p1_WEN));
	sram_4096x8 P_2 (.A(p2_A), .D(p2_D), .Q(p2_Q), 
					.CLK(clk), .CEN(p2_CEN), .WEN(p2_WEN));

	sram_256x8  B_  (.A(b_A),  .D(b_D),  .Q(b_Q),  
					.CLK(clk), .CEN(b_CEN),  .WEN(b_WEN));

	sram_4096x8 X_  (.A(x_A),  .D(x_D),  .Q(x_Q),  
					.CLK(clk), .CEN(x_CEN),  .WEN(x_WEN));


	//Computing
	reg signed [21:0] sum;

	reg signed [7:0] weight_r;
	reg [5:0] position_r;
	reg signed [7:0] vector_r;

	wire signed [15:0] product;
	wire signed [21:0] product_ext;

	assign product = $signed(weight_r) * $signed(vector_r);
	assign product_ext = {{6{product[15]}}, product}; //S4.11 -> S10.11

	reg [1:0] wp_bank;

	wire [13:0] nonzero_index;
	assign nonzero_index = row_count * 14'd48 + nonzero_count;

	reg [7:0] vector_index;


	// position(0~63) <-> vector index
	always @(*) begin
		case (nonzero_count[1:0]) //decide bank
			2'd0: vector_index = 8'd0   + {2'd0, position_r}; // bank0
			2'd1: vector_index = 8'd64  + {2'd0, position_r}; // bank1
			2'd2: vector_index = 8'd128 + {2'd0, position_r}; // bank2
			2'd3: vector_index = 8'd192 + {2'd0, position_r}; // bank3
			default: vector_index = 8'd0;
		endcase
	end

	// SRAM connecting
	always @(*) begin

		w0_CEN = 1'b1; w0_WEN = 1'b1; w0_A = 12'd0; w0_D = 8'd0;
		w1_CEN = 1'b1; w1_WEN = 1'b1; w1_A = 12'd0; w1_D = 8'd0;
		w2_CEN = 1'b1; w2_WEN = 1'b1; w2_A = 12'd0; w2_D = 8'd0;

		p0_CEN = 1'b1; p0_WEN = 1'b1; p0_A = 12'd0; p0_D = 8'd0;
		p1_CEN = 1'b1; p1_WEN = 1'b1; p1_A = 12'd0; p1_D = 8'd0;
		p2_CEN = 1'b1; p2_WEN = 1'b1; p2_A = 12'd0; p2_D = 8'd0;

		b_CEN  = 1'b1; b_WEN  = 1'b1; b_A  = 8'd0;  b_D  = 8'd0;
		x_CEN  = 1'b1; x_WEN  = 1'b1; x_A  = 12'd0; x_D  = 8'd0;

		case (state)

			LOAD_WEIGHT: begin
				if (w_input_valid) begin
					if (load_count < 14'd4096) begin
						w0_CEN = 1'b0;
						w0_WEN = 1'b0;
						w0_A = load_count[11:0];
						w0_D = raw_input;
					end
					else if (load_count < 14'd8192) begin
						w1_CEN = 1'b0;
						w1_WEN = 1'b0;
						w1_A = load_count[11:0];
						w1_D = raw_input;
					end
					else begin
						w2_CEN = 1'b0;
						w2_WEN = 1'b0;
						w2_A = load_count[11:0];
						w2_D = raw_input;
					end
				end
			end


			LOAD_POSITION: begin
				if (w_input_valid) begin
					if (load_count < 14'd4096) begin
						p0_CEN = 1'b0;
						p0_WEN = 1'b0;
						p0_A = load_count[11:0];
						p0_D = raw_input;
					end
					else if (load_count < 14'd8192) begin
						p1_CEN = 1'b0;
						p1_WEN = 1'b0;
						p1_A = load_count[11:0];
						p1_D = raw_input;
					end
					else begin
						p2_CEN = 1'b0;
						p2_WEN = 1'b0;
						p2_A = load_count[11:0];
						p2_D = raw_input;
					end
				end
			end


			LOAD_BIAS: begin
				if (w_input_valid) begin
					b_CEN = 1'b0;
					b_WEN = 1'b0;
					b_A = load_count[7:0];
					b_D = raw_input;
				end
			end

			PRE_LOAD: begin
				if (raw_data_valid) begin
					x_CEN = 1'b0;
					x_WEN = 1'b0;
					x_A = load_count[11:0];
					x_D = raw_input;
				end
			end

			LOAD_VECTOR: begin
				if (raw_data_valid) begin
					x_CEN = 1'b0;
					x_WEN = 1'b0;
					x_A = load_count[11:0];
					x_D = raw_input;
				end
			end


			READ_BIAS: begin
				b_CEN = 1'b0;
				b_WEN = 1'b1;
				b_A = row_count[7:0];
			end


			READ_WP: begin
				if (nonzero_index < 14'd4096) begin
					w0_CEN = 1'b0;
					w0_WEN = 1'b1;
					w0_A   = nonzero_index[11:0];

					p0_CEN = 1'b0;
					p0_WEN = 1'b1;
					p0_A   = nonzero_index[11:0];
				end
				else if (nonzero_index < 14'd8192) begin
					w1_CEN = 1'b0;
					w1_WEN = 1'b1;
					w1_A   = nonzero_index[11:0];

					p1_CEN = 1'b0;
					p1_WEN = 1'b1;
					p1_A   = nonzero_index[11:0];
				end
				else begin
					w2_CEN = 1'b0;
					w2_WEN = 1'b1;
					w2_A = nonzero_index[11:0];

					p2_CEN = 1'b0;
					p2_WEN = 1'b1;
					p2_A = nonzero_index[11:0];
				end
			end

			// address = vector_count * 256 + vector_index(8 bits)
			READ_VECTOR: begin
				x_CEN = 1'b0;
				x_WEN = 1'b1;
				x_A = {vector_count, vector_index};
			end

		endcase
	end



	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= IDLE0;

			raw_data_request <= 1'b0;
			ld_w_request <= 1'b0;
			o_result <= 22'd0;
			o_valid <= 1'b0;

			load_count <= 14'd0;
			row_count <= 9'd0;
			nonzero_count <= 6'd0;
			vector_count <= 4'd0;

			sum <= 22'd0;
			weight_r <= 8'd0;
			position_r <= 6'd0;
			vector_r <= 8'd0;
			wp_bank <= 2'd0;
		end

		else begin
			state <= nextstate;

			raw_data_request <= 1'b0;
			ld_w_request <= 1'b0;
			o_valid <= 1'b0;

			case (state)

				IDLE0: begin
					load_count <= 14'd0;
					row_count  <= 9'd0;
					nonzero_count <= 6'd0;
					vector_count <= 4'd0;
					sum <= 22'd0;
				end

				LOAD_WEIGHT: begin
					ld_w_request <= 1'b1;

					if (w_input_valid) begin
						if (load_count == 14'd12287)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				LOAD_POSITION: begin
					ld_w_request <= 1'b1;

					if (w_input_valid) begin
						if (load_count == 14'd12287)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				LOAD_BIAS: begin
					ld_w_request <= 1'b1;

					if (w_input_valid) begin
						if (load_count == 14'd255)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				IDLE1: begin
					load_count <= 14'd0;
					row_count  <= 9'd0;
					nonzero_count <= 6'd0;
					vector_count <= 4'd0;
					sum <= 22'd0;
				end

				PRE_LOAD: begin
					raw_data_request <= 1'b1;

					if (raw_data_valid) begin
						$display("PRE_LOAD: time=%0t load_count=%0d raw_input=%h", 
							$time, load_count, raw_input);

						if (load_count == 14'd4095)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end
				
				LOAD_VECTOR: begin
					if (raw_data_valid && load_count < 14'd5) begin
						$display("LOAD_VECTOR: time=%0t load_count=%0d raw_input=%h", 
							$time, load_count, raw_input);
					end

					if (raw_data_valid && load_count == 14'd4095)
						raw_data_request <= 1'b0;
					else
						raw_data_request <= 1'b1;

					if (raw_data_valid) begin
						if (load_count == 14'd4095)
							load_count <= 14'd0;
						else
							load_count <= load_count + 14'd1;
					end
				end

				WAIT_LOAD: begin
				end


				READ_BIAS: begin
				end

				WAIT_BIAS: begin
				end

				//sum = bias
				INIT_MULT: begin
					sum <= {{10{b_Q[7]}}, b_Q, 4'b0000}; //S0.7 -> S10.11
					nonzero_count <= 6'd0;
				end

				READ_WP: begin
					if (nonzero_index < 14'd4096)
						wp_bank <= 2'd0;
					else if (nonzero_index < 14'd8192)
						wp_bank <= 2'd1;
					else
						wp_bank <= 2'd2;
				end

				WAIT_WP: begin
				end

				LATCH_WP: begin
					case (wp_bank)
						2'd0: begin
							weight_r <= w0_Q;
							position_r <= p0_Q[5:0];
						end
						2'd1: begin
							weight_r <= w1_Q;
							position_r <= p1_Q[5:0];
						end
						2'd2: begin
							weight_r <= w2_Q;
							position_r <= p2_Q[5:0];
						end
						default: begin
							weight_r <= 8'd0;
							position_r <= 6'd0;
						end
					endcase
				end

				READ_VECTOR: begin
					if (vector_count == 4'd0 && row_count == 9'd0 && nonzero_count < 6'd3) begin
						$display("READ_VECTOR: time=%0t vc=%0d row=%0d nz=%0d vector_index=%0d real_x_A=%0d",
							$time, vector_count, row_count, nonzero_count, vector_index, {vector_count, vector_index});
					end
				end				

				WAIT_VECTOR: begin
					vector_r <= x_Q;
					if (vector_count == 4'd0 && row_count == 9'd0 && nonzero_count < 6'd3) begin
						$display("WAIT_VECTOR: time=%0t vc=%0d row=%0d nz=%0d x_Q=%h vector_r_old=%h",
							$time, vector_count, row_count, nonzero_count, x_Q, vector_r);
					end
				end

				//sum = bias + w0*x0 + w1*x1 + ... + w47*x47
				// bias: S0.7 (changed to S10.11 already)				
				// weight: S2.5
				// vector: S1.6
				// output: S10.11
				CALCULATION: begin
					sum <= sum + product_ext;

					if (nonzero_count == 6'd47)
						nonzero_count <= 6'd0;
					else
						nonzero_count <= nonzero_count + 6'd1;
				end


				OUTPUT: begin
					o_result <= sum;
					o_valid  <= 1'b1;

					if (row_count == 9'd255) begin
						row_count <= 9'd0;

						if (vector_count == 4'd15)
							vector_count <= 4'd0;
						else
							vector_count <= vector_count + 4'd1;
					end
					else begin
						row_count <= row_count + 9'd1;
					end
				end

			endcase
		end
	end



	always @(*) begin
		nextstate = state;

		case (state)

			IDLE0: begin
				if (start_init)
					nextstate = LOAD_WEIGHT;
				else
					nextstate = IDLE0;
			end

			LOAD_WEIGHT: begin
				if (w_input_valid && load_count == 14'd12287)
					nextstate = LOAD_POSITION;
				else
					nextstate = LOAD_WEIGHT;
			end

			LOAD_POSITION: begin
				if (w_input_valid && load_count == 14'd12287)
					nextstate = LOAD_BIAS;
				else
					nextstate = LOAD_POSITION;
			end

			LOAD_BIAS: begin
				if (w_input_valid && load_count == 14'd255)
					nextstate = IDLE1;
				else
					nextstate = LOAD_BIAS;
			end

			IDLE1: begin
				nextstate = PRE_LOAD;
			end

			PRE_LOAD: begin
				nextstate = LOAD_VECTOR;
			end

			LOAD_VECTOR: begin
				if (raw_data_valid && load_count == 14'd4095)
					nextstate = WAIT_LOAD;
				else
					nextstate = LOAD_VECTOR;
			end

			WAIT_LOAD: begin
				nextstate = READ_BIAS;
			end

			READ_BIAS: begin
				nextstate = WAIT_BIAS;
			end

			WAIT_BIAS: begin
				nextstate = INIT_MULT;
			end

			INIT_MULT: begin
				nextstate = READ_WP;
			end

			READ_WP: begin
				nextstate = WAIT_WP;
			end

			WAIT_WP: begin
				nextstate = LATCH_WP;
			end

			LATCH_WP: begin
				nextstate = READ_VECTOR;
			end

			READ_VECTOR: begin
				nextstate = WAIT_VECTOR;
			end

			WAIT_VECTOR: begin
				nextstate = CALCULATION;
			end

			CALCULATION: begin
				if (nonzero_count == 6'd47)
					nextstate = OUTPUT;
				else
					nextstate = READ_WP;
			end

			OUTPUT: begin
				if (row_count == 9'd255 && vector_count == 4'd15)
					nextstate = IDLE1;
				else
					nextstate = READ_BIAS;
			end

			default: begin
				nextstate = IDLE0;
			end

		endcase
	end

endmodule