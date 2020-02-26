// I8257 Core with 8-bit reg built in for 16-bit address in/out
// Run at double system clk frequency as logic uses rising edges only

module i8257(
    input logic clk,
    input logic rst_n,
    input logic cen,

    // Slave signals
    input logic s_ena,
    input logic s_rd,
    input logic s_wr,
    input logic[3:0] s_addr,
    input logic[7:0] s_din,
    output logic[7:0] s_dout,

    // Master signals
    output logic m_memr,
    output logic m_memw,
    output logic m_iord,
    output logic m_iowr,
    output logic[15:0] m_addr,
    input logic[7:0] m_din,
    output logic[7:0] m_dout,

    // DMA Control Signals
    input logic[3:0] drq,
    output logic[3:0] dack,
    
    // Bus Control Signals
    output logic busrq,
    input logic busack,
    input logic ready,

    // Misc signals
    output logic aen,
    output logic adstb,
    output logic tc,
    output logic mark
);

localparam DMAOP_R = 2'b10;
localparam DMAOP_W = 2'b01;
localparam DMAOP_V = 2'b00;

// States
localparam STATE_SI = 7'b0000001;
localparam STATE_S0 = 7'b0000010;
localparam STATE_S1 = 7'b0000100;
localparam STATE_S2 = 7'b0001000;
localparam STATE_S3 = 7'b0010000;
localparam STATE_SW = 7'b0100000;
localparam STATE_S4 = 7'b1000000;

// Internal Register Signals
logic[15:0] dma_addr[0:3];
logic[13:0] dma_cnt[0:3];
logic[1:0]  dma_mode[0:3];
logic       first_last;

logic[7:0]  global_mode;
logic[4:0]  global_status;

// DMA Signals
logic[3:0] drq_sampled;
logic busack_sampled;
logic ready_sampled;

logic do_drq_sample;
logic do_busack_sample;
logic do_ready_sample;

// State Machine Signals
logic[6:0] state, next_state;
logic ps_clock_edge;

// Register Access
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        for(int i = 0; i < $size(dma_addr); ++i) begin
            dma_addr[i] <= 0;
            dma_cnt[i] <= 0;
            dma_mode[i] <= 0;
        end

        first_last <= 1'b0;
        global_mode <= 0;
        global_status <= 0;
    end else if(cen == 1'b1 && ps_clock_edge == 1'b1) begin
        // Address Decode
        if(rd == 1'b1) begin
            casez(s_addr)
            4'b1???: s_dout <= global_status;
            4'b0000: s_dout <= get_reg_half(dma_addr[0]);
            4'b0001: s_dout <= get_reg_half(dma_cnt[0]);
            4'b0010: s_dout <= get_reg_half(dma_addr[1]);
            4'b0011: s_dout <= get_reg_half(dma_cnt[1]);
            4'b0100: s_dout <= get_reg_half(dma_addr[2]);
            4'b0101: s_dout <= get_reg_half(dma_cnt[2]);
            4'b0110: s_dout <= get_reg_half(dma_addr[3]);
            4'b0111: s_dout <= get_reg_half(dma_cnt[3]);
            endcase
        end

        if(wr == 1'b1) begin
            casez(s_addr)
            4'b1???: global_mode <= s_din;
            4'b0000: set_reg_half(dma_addr[0], s_din);
            4'b0001: set_reg_half(dma_cnt[0], s_din);
            4'b0010: set_reg_half(dma_addr[1], s_din);
            4'b0011: set_reg_half(dma_cnt[1], s_din);
            4'b0100: set_reg_half(dma_addr[2], s_din);
            4'b0101: set_reg_half(dma_cnt[2], s_din);
            4'b0110: set_reg_half(dma_addr[3], s_din);
            4'b0111: set_reg_half(dma_cnt[3], s_din);
            endcase
        end

        // Update first_last
        if(s_addr[3] == 1'b1) begin
            first_last <= 0;
        end else if(wr == 1'b1) begin
            first_last <= ~first_last;
        end
    end
end

// Pseudo Clock Edge toggle
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        ps_clock_edge <= 1'b0;
    end else if(cen == 1'b1) begin
        ps_clock_edge <= 1'b1;
    end
end

// Main State Machine
// threedee.com/jcm/terak/docs/Intel%208257%20Programmable%20DMA%20Controller.pdf
// Page 2-111 (9) has flowchart
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        state <= 1'b0;
    end else if(cen == 1'b1 && ps_clock_edge == 1'b0) begin
        state <= next_state; 
    end
end

always_comb
begin
    if(state == STATE_SI) begin
        // Sample DRQn Lines
        // Set HRQ if DRQn = 1
        if(|(drq_sampled))
            next_state <= STATE_S0;
        else
            next_state <= STATE_SI;
    end else if(state == STATE_S0) begin
        // Sample BUSACK
        // Resolve DRQn Priorities
        if(busack_sampled)
            next_state <= STATE_S1
        else
            next_state <= STATE_S0;
    end else if(state == STATE_S1) begin
        // Present and latch upper address
        // Present lower address
        next_state <= STATE_S2;
    end else if(state == STATE_S2) begin
        // Activate read command,
        // Advanced write command,
        // and DACKn
        next_state <= STATE_S3;
    end else if(state == STATE_S3) begin
        // Activate write command,
        // Activate MARK and TC if appropriate
        // Sample Ready Line
        if(ready_sampled)
            next_state <= STATE_S4;
        else
            next_state <= STATE_SW;
    end else if(state == STATE_SW) begin
        // Sample Ready Line
        if(ready_sampled)
            next_state <= STATE_S4;
        else
            next_state <= STATE_SW;
    end else if(state == STATE_S4) begin
        // Reset enable for channel N if
        // TC stop and TC are active
        // Deactivate commands
        // Deactivate DACKn, MARK, TC
        // Sample DRQn, BUSACK
        // Resolve DRQn Priorities
        // Reset BUSRQ if BUSACK = 0 or DRQ = 0
        if(~busack_sampled & ~|(drq_sampled))
            next_state <= STATE_SI;
        else
            next_state <= STATE_S1;
    end else begin
        next_state <= STATE_SI;
    end
end

// Output signals
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        dack    <= 4'b0000;
        aen     <= 1'b0;
        adstb   <= 1'b0;
        tc      <= 1'b0;
        mark    <= 1'b0;

        m_memr <= 1'b0;
        m_memw <= 1'b0;
        m_iord <= 1'b0;
        m_iowr <= 1'b0;
    end else if(cen == 1'b1) begin

    end
end

// Samplers
assign do_drq_sample =
    (ps_clock_edge == 1 && state == STATE_SI) ||    // Falling in SI
    (ps_clock_edge == 1 && state == STATE_S3);      // Falling in S4

assign do_busack_sample = 
    (ps_clock_edge == 1 && state == STATE_S0) ||    // Falling in S1
    (ps_clock_edge == 1 && state == STATE_S3);      // Falling in S4

assign do_ready_sample =
    (ps_clock_edge == 0 && state == STATE_S3) ||    // Rising in S3 
    (ps_clock_edge == 0 && state == STATE_SW);      // Rising in SW

always_ff @(posedge clk) begin
    if(rst_n == 1'b0) begin
        drq_sampled <= 0;
        busack_sampled <= 0;
        ready_sampled <= 0;
    end else if(cen == 1'b1) begin
        if(do_drq_sample)
            drq_sampled <= drq;

        if(do_busack_sample
            busack_sampled <= busack;

        if(do_ready_sampled)
            ready_sampled <= ready;
    end
end

// Internal Register Helpers
function logic[7:0] get_reg_half(logic[15:0] r);
    if(first_last == 0)
        get_reg_half = r[7:0];
    else
        get_reg_half = r[15:8];
end

function void set_reg_half(ref logic[15:0] r, logic[7:0] d);
    if(first_last == 0)
        r[7:0] <= d;
    else
        r[15:8] <= d;
end

endmodule
