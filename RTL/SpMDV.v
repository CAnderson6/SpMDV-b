module SpMDV 
(
    input clk,
    input rst,
    input start_init,
    input [7 : 0] raw_input,
    input raw_data_valid,
    input w_input_valid,
    output reg raw_data_request,
    output reg ld_w_request,
    output reg [21 : 0] o_result,
    output reg o_valid
);

    // [修正] 控制計數器
    reg [13:0] load_count; 
    reg [8:0]  row_count; 
    reg [5:0]  nzv_idx;     // 0~47，代表目前 row 裡的第幾個非零值 [cite: 333]
    reg [3:0]  token_idx;   // 0~15，處理 16 個 dense vectors [cite: 1230, 1279]
    reg [1:0]  bank_sel;    // 0~3，代表目前的 bank 

    // 狀態機定義 [cite: 1289]
    localparam IDLE         = 4'd0;
    localparam LD_W         = 4'd1;
    localparam LD_P         = 4'd2;
    localparam LD_B         = 4'd3;
    localparam LD_V         = 4'd4;
    localparam RD_B         = 4'd5;
    localparam CALC_INIT    = 4'd6;
    localparam RD_WP        = 4'd7;
    localparam CALC_WAIT    = 4'd8; // 等待 SRAM 讀取 
    localparam CALC_CORE    = 4'd9;
    localparam DONE_TOKEN   = 4'd10;

    reg [3:0] state, next_state;

    // SRAM 介面元件 [cite: 1296]
    // 這裡我們必須依照傳輸順序來儲存：nzv0_b0, nzv0_b1, nzv0_b2, nzv0_b3...
    // 這樣在計算時，同一個 cycle 讀出的 W 和 P 才會是一對的。
    reg [11:0] wa, pa, xa;
    wire [7:0] wq, pq, xq, bq;
    reg wen_w, wen_p, wen_b, wen_x;

    sram_4096x8 W_RAM (.A(wa), .D(raw_input), .Q(wq), .CLK(clk), .CEN(1'b0), .WEN(wen_w));
    sram_4096x8 P_RAM (.A(pa), .D(raw_input), .Q(pq), .CLK(clk), .CEN(1'b0), .WEN(wen_p));
    sram_256x8  B_RAM (.A(row_count[7:0]), .D(raw_input), .Q(bq), .CLK(clk), .CEN(1'b0), .WEN(wen_b));
    sram_4096x8 V_RAM (.A(xa), .D(raw_input), .Q(xq), .CLK(clk), .CEN(1'b0), .WEN(wen_x));

    // 計算單元 
    reg signed [21:0] sum;
    wire signed [15:0] prod = $signed(wq) * $signed(xq); 
    wire signed [21:0] prod_ext = {{6{prod[15]}}, prod}; // S4.11 -> S10.11 [cite: 1267, 1270]

    // 向量位址索引修正 [cite: 332, 1236]
    // 位址 = token_idx * 256 + (bank_sel * 64 + pq)
    wire [11:0] current_v_addr = {token_idx, bank_sel, pq[5:0]};

    // [核心修正] SRAM 地址控制邏輯
    always @(*) begin
        wen_w = 1; wen_p = 1; wen_b = 1; wen_x = 1;
        wa = load_count[11:0]; pa = load_count[11:0];
        xa = (state == LD_V) ? load_count[11:0] : current_v_addr;
        
        case(state)
            LD_W: wen_w = ~w_input_valid;
            LD_P: wen_p = ~w_input_valid;
            LD_B: wen_b = ~w_input_valid;
            LD_V: wen_x = ~raw_data_valid;
        endcase
    end

    // FSM 控制
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            {load_count, row_count, nzv_idx, token_idx, bank_sel} <= 0;
            o_valid <= 0;
        end else begin
            state <= next_state;
            
            case(state)
                IDLE: begin load_count <= 0; o_valid <= 0; end
                LD_W, LD_P: if(w_input_valid) load_count <= (load_count == 12287) ? 0 : load_count + 1;
                LD_B: if(w_input_valid) load_count <= (load_count == 255) ? 0 : load_count + 1;
                LD_V: begin
                    raw_data_request <= 1;
                    if(raw_data_valid) load_count <= (load_count == 4095) ? 0 : load_count + 1;
                end
                CALC_INIT: begin
                    sum <= {{10{bq[7]}}, bq, 4'b0000}; // 初始化 sum 為 bias [cite: 1260, 1265]
                    nzv_idx <= 0;
                    bank_sel <= 0;
                end
                RD_WP: begin
                    wa <= row_count * 48 + nzv_idx;
                    pa <= row_count * 48 + nzv_idx;
                    bank_sel <= nzv_idx[1:0]; // 依照 0,1,2,3 循環對應 bank [cite: 878]
                end
                CALC_CORE: begin
                    sum <= sum + prod_ext;
                    if(nzv_idx == 47) begin
                        o_result <= sum + prod_ext; // 最後一次累加 
                        o_valid <= 1;
                    end
                    nzv_idx <= nzv_idx + 1;
                end
                DONE_TOKEN: begin
                    o_valid <= 0;
                    if(row_count == 255) begin
                        row_count <= 0;
                        token_idx <= token_idx + 1;
                    end else row_count <= row_count + 1;
                end
            endcase
        end
    end

    // 狀態轉移
    always @(*) begin
        next_state = state;
        case(state)
            IDLE: if(start_init) next_state = LD_W;
            LD_W: if(w_input_valid && load_count == 12287) next_state = LD_P;
            LD_P: if(w_input_valid && load_count == 12287) next_state = LD_B;
            LD_B: if(w_input_valid && load_count == 255) next_state = LD_V;
            LD_V: if(raw_data_valid && load_count == 4095) next_state = RD_B;
            RD_B: next_state = CALC_INIT;
            CALC_INIT: next_state = RD_WP;
            RD_WP: next_state = CALC_WAIT;
            CALC_WAIT: next_state = CALC_CORE;
            CALC_CORE: next_state = (nzv_idx == 47) ? DONE_TOKEN : RD_WP;
            DONE_TOKEN: next_state = (token_idx == 15 && row_count == 0) ? IDLE : RD_B;
        endcase
    end

    assign ld_w_request = (state == LD_W || state == LD_P || state == LD_B);

endmodule