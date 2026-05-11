module SpMDV 
(
	input clk,
	input rst,

	// Input signals
	input start_init,
    input [7 : 0] raw_input,
    input raw_data_valid,
	input w_input_valid,

	// Ouput signals
    output reg raw_data_request,
	output reg ld_w_request,
	output reg [21 : 0] o_result,
	output reg o_valid
);

	//Counter
    reg [13:0] load_cnt; //0 ~ 12287
    reg [8:0]  row_cnt; //0 ~ 255
    reg [5:0]  nz_cnt; //0 ~ 47


	//FSM States
    localparam IDLE0         = 4'd0;
    localparam LOAD_WEIGHT   = 4'd1;
    localparam LOAD_POSITION = 4'd2;
    localparam LOAD_BIAS     = 4'd3;
    localparam IDLE1         = 4'd4;
    localparam LOAD_VECTOR   = 4'd5;
    localparam INIT_ROW      = 4'd6;
    localparam COMPUTE       = 4'd7;
    localparam OUTPUT        = 4'd8;

	reg [3:0] state;
	reg [3:0] next_state;


	//Main
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			state <= IDLE0;

			raw_data_request <= 1'b0;
			ld_w_request     <= 1'b0;
			o_result         <= 22'd0;
			o_valid          <= 1'b0;

			load_cnt <= 14'd0;
			row_cnt  <= 9'd0;
			nz_cnt   <= 6'd0;
		end
		else begin
			state <= next_state;

			raw_data_request <= 1'b0;
			ld_w_request     <= 1'b0;
			o_valid          <= 1'b0;

			case (state)

				IDLE0: begin
					load_cnt <= 14'd0;
					row_cnt  <= 9'd0;
					nz_cnt   <= 6'd0;
				end

				LOAD_WEIGHT: begin
					ld_w_request <= 1'b1;

					if (w_input_valid) begin
						weight[load_cnt] <= raw_input;

						if (load_cnt == 12287)
							load_cnt <= 14'd0;
						else
							load_cnt <= load_cnt + 14'd1;
					end
				end

				LOAD_POSITION: begin
					ld_w_request <= 1'b1;

					if (w_input_valid) begin
						pos[load_cnt] <= raw_input[5:0];

						if (load_cnt == 12287)
							load_cnt <= 14'd0;
						else
							load_cnt <= load_cnt + 14'd1;
					end
				end

				LOAD_BIAS: begin
					ld_w_request <= 1'b1;

					if (w_input_valid) begin
						bias[load_cnt] <= raw_input;

						if (load_cnt == 255)
							load_cnt <= 14'd0;
						else
							load_cnt <= load_cnt + 14'd1;
					end
				end

				IDLE1: begin
					load_cnt <= 14'd0;
					row_cnt  <= 9'd0;
					nz_cnt   <= 6'd0;
					acc      <= 22'd0;
				end

				LOAD_VECTOR: begin
					raw_data_request <= 1'b1;

					if (raw_data_valid) begin
						x[load_cnt] <= raw_input;

						if (load_cnt == 255)
							load_cnt <= 14'd0;
						else
							load_cnt <= load_cnt + 14'd1;
					end
				end

				INIT_ROW: begin
					nz_cnt <= 6'd0;
					acc <= {{14{bias[row_cnt][7]}}, bias[row_cnt]};
				end

				COMPUTE: begin
					if (nz_cnt < 48) begin
						acc <= acc + weight[nz_index] * x[pos[nz_index]];
						nz_cnt <= nz_cnt + 6'd1;
					end
				end

				OUTPUT: begin
					o_result <= acc;
					o_valid  <= 1'b1;

					if (row_cnt == 255)
						row_cnt <= 9'd0;
					else
						row_cnt <= row_cnt + 9'd1;

					nz_cnt <= 6'd0;
				end

			endcase
		end
	end



	always @(*) begin

		next_state = state;

        case (state)

            IDLE0: begin
                if (start_init)
                    next_state = LOAD_WEIGHT;
                else
                    next_state = IDLE0;
            end

            LOAD_WEIGHT: begin
                if (w_input_valid && load_cnt == 12287)
                    next_state = LOAD_POSITION;
                else
                    next_state = LOAD_WEIGHT;
            end

            LOAD_POSITION: begin
                if (w_input_valid && load_cnt == 12287)
                    next_state = LOAD_BIAS;
                else
                    next_state = LOAD_POSITION;
            end

            LOAD_BIAS: begin
                if (w_input_valid && load_cnt == 255)
                    next_state = IDLE1;
                else
                    next_state = LOAD_BIAS;
            end

            IDLE1: begin
                next_state = LOAD_VECTOR;
            end

            LOAD_VECTOR: begin
                if (raw_data_valid && load_cnt == 255)
                    next_state = INIT_ROW;
                else
                    next_state = LOAD_VECTOR;
            end

            INIT_ROW: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if (nz_cnt == 48)
                    next_state = OUTPUT;
                else
                    next_state = COMPUTE;
            end

            OUTPUT: begin
                if (row_cnt == 255)
                    next_state = IDLE1;
                else
                    next_state = INIT_ROW;
            end

            default: begin
                next_state = IDLE0;
            end

        endcase
    end


endmodule