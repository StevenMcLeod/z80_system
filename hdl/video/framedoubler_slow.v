//
//  Donkey Kong FrameDoubler
//
//  Input 256x224 Video (Follows CRT Scanbeam)
//  Output 640x480 VGA
//  Starts VGA frame after one input line
//  Stores input frame in fifo
//
//  At RST input must be in VBLANK
//
//  16 line border at top/bottom + 64 pixel spacing at left/right
//

module framedoubler_slow(
    input wire masterclk,
    input wire in_rst_n,

    input wire in_pixclk,
    input wire in_valid,
    input wire[2:0] in_r,
    input wire[2:0] in_g,
    input wire[1:0] in_b,

    input wire out_pixclk,
    input wire out_rst_n,
    output reg[3:0] out_r,
    output reg[3:0] out_g,
    output reg[3:0] out_b,
    output reg hsync, 
    output reg vsync
);

localparam IN_WIDTH = 256;
localparam IN_HEIGHT = 224;
localparam OUT_WIDTH = 640;
localparam OUT_HEIGHT = 480;

localparam BORDER_WIDTH = 64;
localparam BORDER_HEIGHT = 16;

localparam BORDER_R = 4'b1111;
localparam BORDER_G = 4'b0000;
localparam BORDER_B = 4'b0000;

localparam INVERTED_VIDEO = 1;

localparam OUT_HFP = 16;
localparam OUT_HSYNC = 96;
localparam OUT_HBP = 48;
localparam OUT_HTOTAL = OUT_HFP + OUT_HSYNC + OUT_HBP + OUT_WIDTH;
localparam HSYNC_ACTIVE = 0;

localparam OUT_VFP = 10;
localparam OUT_VSYNC = 2;
localparam OUT_VBP = 33;
localparam OUT_VTOTAL = OUT_VFP + OUT_VSYNC + OUT_VBP + OUT_HEIGHT;
localparam VSYNC_ACTIVE = 0;


//localparam FIFO_ENTRY_W = $bits({in_b, in_g, in_r});
localparam NUM_FIFOS = 2;
localparam FIFO_ENTRY_W = 8;
localparam FIFO_DEPTH = IN_WIDTH * IN_HEIGHT;
localparam FIFO_ADDR_W = $clog2(FIFO_DEPTH - 1);
localparam FRAME_DELAY = NUM_FIFOS - 1;

reg[$clog2(NUM_FIFOS)-1 : 0] frame_in_parity;
reg done_in_pixel;
wire in_do_write;

reg[FIFO_ADDR_W-1 : 0] in_ptr;
wire[FIFO_ADDR_W-1 : 0] out_ptr;

wire[FIFO_ENTRY_W-1 : 0] in_data;
wire[FIFO_ENTRY_W-1 : 0] out_data[0 : NUM_FIFOS-1];
wire[FIFO_ENTRY_W-1 : 0] real_out_data;
reg[$clog2(IN_HEIGHT)-1 : 0] out_line;
reg[$clog2(IN_WIDTH)-1 : 0] out_pix;

reg out_of_reset;
reg[$clog2(OUT_HTOTAL)-1:0] out_hcount;
reg[$clog2(OUT_VTOTAL)-1:0] out_vcount;
reg[$clog2(NUM_FIFOS)-1 : 0] frame_out_parity, outclk_frame_in_parity;
reg pix_rep_count, line_rep_count;

wire hblk, vblk, cmpblk;
wire hborder, vborder, cmpborder;

// SRAM Generators
genvar i;
generate
for(i = 0; i < 2; i = i + 1) begin : gen_mem
    framedoubler_mem mem (
        .clka(masterclk),
        .wea(in_do_write && frame_in_parity == i),
        .addra(in_ptr),
        .dina(in_data),
        
        .clkb(out_pixclk),
        .addrb(out_ptr),
        .doutb(out_data[i])
    );
end
endgenerate

// Input Handler
assign in_data = {in_b, in_g, in_r} ^ {8{INVERTED_VIDEO[0]}};

assign in_do_write = in_valid && in_pixclk && !done_in_pixel;

always @(posedge masterclk)
begin
    if(in_rst_n == 1'b0) begin
        in_ptr <= 0;
        done_in_pixel <= 0;
        frame_in_parity <= 0;
    end else if(in_do_write) begin
        // On rising of in_pixclk
        done_in_pixel <= 1;

        // Inc fifo ptr
        if(in_ptr == FIFO_DEPTH - 1) begin
            // Reset ptr and choose next fifo
            in_ptr <= 0;

            if(frame_in_parity == NUM_FIFOS - 1)
                frame_in_parity <= 0;
            else
                frame_in_parity <= frame_in_parity + 1;
        end else begin
            // Only inc ptr
            in_ptr <= in_ptr + 1;
        end
    end else if(in_pixclk == 0) begin
        done_in_pixel <= 0;
    end
end

// Output Handler
assign hblk = out_hcount >= OUT_WIDTH;
assign vblk = out_vcount >= OUT_HEIGHT;
assign cmpblk = hblk | vblk;

assign hborder = ~hblk && (
                        (out_hcount < BORDER_WIDTH)
                    ||  (out_hcount >= BORDER_WIDTH + 2*IN_WIDTH)
                );
assign vborder = ~vblk && (
                        (out_vcount < BORDER_HEIGHT)
                    ||  (out_vcount >= BORDER_HEIGHT + 2*IN_HEIGHT)
                 );
assign cmpborder = hborder | vborder;

assign out_ptr = (out_line * IN_WIDTH) + out_pix;
assign real_out_data = out_data[frame_out_parity];

always @(posedge out_pixclk)
begin
    outclk_frame_in_parity <= frame_in_parity;

    if(out_rst_n == 1'b0) begin
        out_of_reset <= 1'b1;
        out_hcount <= 0;
        out_vcount <= 0;

        out_line <= 0;
        out_pix <= 0;

        pix_rep_count <= 0;
        line_rep_count <= 0;
        frame_out_parity <= 0;

        out_r <= 0;
        out_g <= 0;
        out_b <= 0;
        hsync <= ~HSYNC_ACTIVE;
        vsync <= ~VSYNC_ACTIVE;
    end else if(out_of_reset == 1'b1) begin
        // Stagger output so input a frame ahead
        if(outclk_frame_in_parity == FRAME_DELAY) begin
            out_of_reset <= 1'b0;
            frame_out_parity <= 0;
        end
    end else begin
        // Handle HSync
        if(out_hcount < OUT_WIDTH + OUT_HFP) begin
            hsync <= ~HSYNC_ACTIVE;
        end else if(out_hcount < OUT_WIDTH + OUT_HFP + OUT_HSYNC) begin
            hsync <= HSYNC_ACTIVE;
        end else begin
            hsync <= ~HSYNC_ACTIVE;
        end

        // Handle VSync
        if(out_vcount < OUT_HEIGHT + OUT_VFP) begin
            vsync <= ~VSYNC_ACTIVE;
        end else if(out_vcount < OUT_HEIGHT + OUT_VFP + OUT_VSYNC) begin
            vsync <= VSYNC_ACTIVE;
        end else begin
            vsync <= ~VSYNC_ACTIVE;
        end

        // Handle color output
        if(cmpblk) begin
            out_r <= 0;
            out_g <= 0;
            out_b <= 0;
        end else if(cmpborder) begin
            if(out_hcount[0] ^ out_vcount[0]) begin
                out_r <= BORDER_R;
                out_g <= BORDER_G;
                out_b <= BORDER_B;
            end else begin
                out_r <= ~BORDER_R;
                out_g <= ~BORDER_G;
                out_b <= ~BORDER_B;
            end
        end else if(line_rep_count == 1'b1) begin
            out_r <= 0;
            out_g <= 0;
            out_b <= 0;
        end else begin
            out_r <= {real_out_data[2:0], 1'b0};
            out_g <= {real_out_data[5:3], 1'b0};
            out_b <= {real_out_data[7:6], 2'b00};
        end

        // Handle pix/line doubler
        if(~cmpblk && ~cmpborder) begin
            pix_rep_count <= ~pix_rep_count;
            
            // Handle out_pix
            if(pix_rep_count == 1'b1) begin
                // Inc out_pix
                if(out_pix == IN_WIDTH - 1) begin
                    out_pix <= 0;
                end else begin
                    out_pix <= out_pix + 1;
                end
            end

            // Handle line_rep_count
            if(pix_rep_count == 1'b1
            && out_pix == IN_WIDTH - 1) begin
                line_rep_count <= ~line_rep_count;
            end

            // Handle out_line
            if(pix_rep_count == 1'b1
            && out_pix == IN_WIDTH - 1
            && line_rep_count == 1'b1) begin
                // Inc out_line
                if(out_line == IN_HEIGHT - 1) begin
                    // Wait for next fifo to be complete
                    //if(outclk_frame_in_parity == frame_out_parity) begin
                        out_line <= 0;
                    //end
                end else begin
                    out_line <= out_line + 1;
                end
            end
        end
            
        // Handle frame_out_parity
        if(out_hcount == 0 && out_vcount == 0) begin
            if(frame_out_parity == NUM_FIFOS - 1)
                frame_out_parity <= 0;
            else
                frame_out_parity <= frame_out_parity + 1;
        end

        // Increment counts
        if(out_hcount == OUT_HTOTAL - 1) begin
            out_hcount <= 0;

            if(out_vcount == OUT_VTOTAL - 1) begin
                out_vcount <= 0;
            end else begin
                out_vcount <= out_vcount + 1;
            end

        end else begin
            out_hcount <= out_hcount + 1;
        end
    end
end

endmodule

