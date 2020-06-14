module DRAM_wrapper(
    input   clk,
    input   rst,
    input   [31:0]  DMA_start,DMA_end;
    input   [31:0]  ADDR;
    output  logic   [31:0]  DATA;
    // // AHB -> slave
    // input [`AHB_TRANS_BITS-1:0] HTRANS,
    // input [`AHB_ADDR_BITS-1:0] HADDR,
    // input HWRITE,
    // input [`AHB_SIZE_BITS-1:0] HSIZE,
    // input [`AHB_BURST_BITS-1:0] HBURST,
    // input [`AHB_PROT_BITS-1:0] HPROT,
    // input [`AHB_DATA_BITS-1:0] HWDATA,
    // input [`AHB_MASTER_BITS-1:0] HMASTER,
    // input HMASTLOCK,
    // input HSEL,
    // input HREADY,
    // from DRAM
    input   DRAM_W;         //active low
    input   DRAM_access;
    input   [31:0]  DRAM_Q,
    input   [1:0]   SIZE;
    // // slave -> AHB
    // output logic [`AHB_DATA_BITS-1:0] HRDATA,
    // output logic HREADY_S4,
    // output logic [`AHB_RESP_BITS-1:0] HRESP,
    // to DRAM
    output  logic   DRAM_CSn,
    output  logic   DRAM_RASn,
    output  logic   DRAM_CASn,
    output  logic   [3:0]   DRAM_WEn,
    output  logic   [11:0]  DRAM_A,
    output  logic   [31:0]  DRAM_D,

    //
    output  logic   data_ready;
    output  logic   store_done;
);

    logic   [2:0]   cur_state,next_state;
    logic   l_w;
    logic   [2:0]   l_s;
    logic   [31:0]  l_a;


    always_comb
    begin
        DATA    =   DRAM_Q;
        DRAM_CSn = (cur_state == 3'b000) && ~DRAM_access;
        DRAM_RASn = (cur_state == 3'b000) && ~DRAM_access;
        DRAM_CASn = (cur_state == 3'b000);
        DRAM_A = (cur_state == 3'b000) ? ADDR[22:12] : {1'b0, l_a[11:2]};
    end


    always_ff @(posedge clk, posedge rst) begin
        if(rst)
            cur_state   <=  3'b0;
        else
            cur_state   <=  next_state;
    end

    always_comb 
    begin
        case(cur_state)
            3'b000: 
                if(DRAM_access)
                    NState = 3'b001;
                else
                    NState = 3'b000;
            3'b001:
                if(l_w)
                    NState = 3'b000;
                else
                    NState = 3'b010;
            3'b010:
                NState = 3'b011;
            3'b011:
                NState = 3'b100;
            3'b100:
                NState = 3'b000;
            default:
                NState = 3'b000;
        endcase
    end

    always_ff @(posedge clk, posedge rst) begin
        if(rst) 
        begin
            l_w <= 1'b0;
            l_s <= 3'b0;
            l_a <= 32'b0;
        end
        else if(DRAM_access) 
        begin
            l_w <=  DRAM_W;
            l_s <=  SIZE;
            l_a <=  ADDR;
        end
    end
















endmodule