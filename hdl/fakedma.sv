`include "Z80Bus.vh"

//; TC_STOP | ROT_PRIO | CH_1 | CH_0
//b@780F = 53
// 
//; CH0_ADDR = 6900
//b@7800 = 00 
//b@7800 = 69 
//
//; CH0_CNT = WR | 0x180
//b@7801 = 80 
//b@7801 = 41 
//
//; CH1_ADDR = 7000
//b@7802 = 00 
//b@7802 = 70 
//
//; CH1_CNT = RD | 0x180
//b@7803 = 80 
//b@7803 = 81


module fakedma (
    input logic clk,
    input logic rst_n,
    input logic cen,

    // Slave Signals
    input logic ena,
    input Z80MasterBus s_ibus,
    output Z80SlaveBus s_obus,
    
    // Master Signals
    output Z80MasterBus m_obus,
    input Z80SlaveBus m_ibus,

    // Bus Control Signals
    output logic busrq,
    input logic busack,
    input logic dma_wait,
    input logic rdy
);

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

logic do_intern_upd;
logic intern_input_sel;
logic do_update_fl;

logic rdn_d, wrn_d;
logic rdn_rise, wrn_rise;

// Internal Reigster Self-Update
logic[3:0] drq;
logic[3:0] do_incdec;

// RD / WR Storage
logic[7:0]  dma_value;

// DMA Signals
logic[6:0] state, next_state;
logic drqn, next_drqn;

assign s_obus.mwait = 1'b1;
assign m_obus.inta = 1'b0;

// Register Access
assign intern_input_sel = (~s_ibus.rdn | ~s_ibus.wrn) && ena && state == STATE_SI;
assign do_intern_upd = |(do_incdec) | intern_input_sel;
assign do_update_fl = ena && (rdn_rise || wrn_rise); 
assign rdn_rise = (rdn_d == 1'b0 && s_ibus.rdn == 1'b1);
assign wrn_rise = (wrn_d == 1'b0 && s_ibus.wrn == 1'b1);

assign drq = {
    dma_cnt[3] != 0,
    dma_cnt[2] != 0,
    dma_cnt[1] != 0,
    dma_cnt[0] != 0
};

assign global_status = {
    4'b0000,
    dma_cnt[3] == 0,
    dma_cnt[2] == 0,
    dma_cnt[1] == 0,
    dma_cnt[0] == 0
};

always_ff @(posedge clk)
begin
    rdn_d <= s_ibus.rdn;
    wrn_d <= s_ibus.wrn;

    if(rst_n == 1'b0) begin
        for(int i = 0; i < $size(dma_addr); ++i) begin
            dma_addr[i] <= 0;
            dma_cnt[i] <= 0;
            dma_mode[i] <= 0;
        end

        global_mode <= 0;
    end else if(cen == 1'b1 && do_intern_upd) begin
        // On rdn == 0 || wrn == 0, only bus can update internals
        // Else, only self can update internals

        if(intern_input_sel == 1'b1) begin  // Input from bus
            // Address Decode
            if(s_ibus.rdn == 1'b0) begin
                casez(s_ibus.addr[3:0])
                4'b1???: s_obus.dslave <= global_status;
                
                4'b0000: s_obus.dslave <= get_reg_half(dma_addr[0]);
                4'b0010: s_obus.dslave <= get_reg_half(dma_addr[1]);
                4'b0100: s_obus.dslave <= get_reg_half(dma_addr[2]);
                4'b0110: s_obus.dslave <= get_reg_half(dma_addr[3]);
                
                4'b0001: s_obus.dslave <= get_reg_half(dma_cnt[0]);
                4'b0011: s_obus.dslave <= get_reg_half(dma_cnt[1]);
                4'b0101: s_obus.dslave <= get_reg_half(dma_cnt[2]);
                4'b0111: s_obus.dslave <= get_reg_half(dma_cnt[3]);
                endcase
            end

            if(s_ibus.wrn == 1'b0) begin
                casez(s_ibus.addr[3:0])
                4'b1???: global_mode <= s_ibus.dmaster;

                4'b0000: dma_addr[0] <= calc_reg_half(dma_addr[0], s_ibus.dmaster);
                4'b0010: dma_addr[1] <= calc_reg_half(dma_addr[1], s_ibus.dmaster);
                4'b0100: dma_addr[2] <= calc_reg_half(dma_addr[2], s_ibus.dmaster);
                4'b0110: dma_addr[3] <= calc_reg_half(dma_addr[3], s_ibus.dmaster);

                4'b0001: {dma_mode[0], dma_cnt[0]} <= calc_reg_half({dma_mode[0], dma_cnt[0]}, s_ibus.dmaster);
                4'b0011: {dma_mode[1], dma_cnt[1]} <= calc_reg_half({dma_mode[1], dma_cnt[1]}, s_ibus.dmaster);
                4'b0101: {dma_mode[2], dma_cnt[2]} <= calc_reg_half({dma_mode[2], dma_cnt[2]}, s_ibus.dmaster);
                4'b0111: {dma_mode[3], dma_cnt[3]} <= calc_reg_half({dma_mode[3], dma_cnt[3]}, s_ibus.dmaster);
                endcase
            end
        end else begin      // Input from self
            for(int i = 0; i < 4; ++i) begin
                if(do_incdec[i]) begin
                    dma_addr[i] <= dma_addr[i] + 1;
                    dma_cnt[i] <= dma_cnt[i] - 1;
                end
            end
        end
    end
end

// Update first_last
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        first_last <= 1'b0;
    end else if(cen == 1'b1 && do_update_fl) begin
        if(s_ibus.addr[3] == 1'b1)
            first_last <= 1'b0;
        else
            first_last <= ~first_last;
    end
end

// DMA State
always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        state <= STATE_SI;
        drqn <= 1'b0;
    end else if(cen == 1'b1) begin
        state <= next_state;
        drqn <= next_drqn;
    end
end

// Next State Calculation
always_comb
begin
    next_state <= STATE_SI;
    next_drqn <= drqn;
    do_incdec <= 4'b0000;

    if(state == STATE_SI) begin
        // Sample RDY, see if we have work to do
        if(rdy && dma_cnt[drqn] != 0)
            next_state <= STATE_S0;
        else
            next_state <= STATE_SI;
    end else if(state == STATE_S0) begin
        // Sample BUSACK
        if(busack)
            next_state <= STATE_S1;
        else
            next_state <= STATE_S0;
    end else if(state == STATE_S1) begin
        next_state <= STATE_S2;
    end else if(state == STATE_S2) begin
        next_state <= STATE_S3;
    end else if(state == STATE_S3) begin
        // Check for wait
        if(dma_wait)
            next_state <= STATE_SW;
        else
            next_state <= STATE_S4;
    end else if(state == STATE_SW) begin
        // Check for wait
        if(dma_wait)
            next_state <= STATE_SW;
        else
            next_state <= STATE_S4;
    end else if(state == STATE_S4) begin
        // Check BUSACK, RDY
        if(busack && rdy && dma_cnt[next_drqn] != 0)
            next_state <= STATE_S1;
        else
            next_state <= STATE_SI;

        next_drqn <= ~drqn;
        do_incdec <= (1 << drqn);
    end
end

always_ff @(posedge clk)
begin
    if(rst_n == 1'b0) begin
        m_obus.mreqn <= 1'b1;
        m_obus.iorqn <= 1'b1;
        m_obus.rdn <= 1'b1;
        m_obus.wrn <= 1'b1;
        busrq <= 1'b0;
        //do_incdec <= 4'b0000;
    end else if(cen == 1'b1) begin
        if(next_state == STATE_SI) begin
            // Reset Bus Signals
            m_obus.mreqn <= 1'b1;
            m_obus.iorqn <= 1'b1;
            m_obus.rdn <= 1'b1;
            m_obus.wrn <= 1'b1;
            busrq <= 1'b0;
        end else if(next_state == STATE_S0) begin
            // Assert BUSRQ
            busrq <= 1'b1;
        end else if(next_state == STATE_S1) begin
            // Display Addr
            //do_incdec <= 4'b0000;
            m_obus.addr <= dma_addr[next_drqn];
        end else if(next_state == STATE_S2) begin
            // Display RD or WR
            // RD / WR is perspective of internal 8-bit port
            m_obus.mreqn <= 1'b0;
            if(dma_mode[drqn][1])     // RD
                m_obus.wrn <= 1'b0;
            else                    // WR
                m_obus.rdn <= 1'b0;
        end else if(next_state == STATE_S3) begin
            // On Read: Store Internal
            // On Write: Show Internal
            if(dma_mode[drqn][1])     // RD
                m_obus.dmaster <= dma_value;
            else                // WR
                dma_value <= m_ibus.dslave;
        end else if(next_state == STATE_S4) begin
            // Release Signals
            // ++addr
            // --cnt
            m_obus.mreqn <= 1'b1;
            m_obus.iorqn <= 1'b1;
            m_obus.rdn <= 1'b1;
            m_obus.wrn <= 1'b1;
            //do_incdec <= (1 << drqn);
        end
    end
end

// Internal Register Helpers
function automatic logic[7:0] get_reg_half(logic[15:0] r);
    if(first_last == 0)
        get_reg_half = r[7:0];
    else
        get_reg_half = r[15:8];
endfunction

function automatic logic[15:0] calc_reg_half(logic[15:0] r, logic[7:0] d);
    calc_reg_half = r;

    if(first_last == 0) begin
        calc_reg_half[7:0] = d;
    end else begin
        calc_reg_half[15:8] = d;
    end
endfunction

endmodule
