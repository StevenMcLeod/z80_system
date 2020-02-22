//
//  Donkey Kong FrameDoubler
//
//  Input 256x224 Video (Follows CRT Scanbeam)
//  Output 640x480 VGA
//  Starts VGA frame after one input line
//  Stores input line in fifo
//
//  At RST input must be in VBLANK
//
//  16 line border at top/bottom + 64 pixel spacing at left/right
//

module framedoubler(
    input wire masterclk,
    input wire rst_n,

    input wire in_pixclk,
    input wire in_valid,
    input wire[2:0] in_r,
    input wire[2:0] in_g,
    input wire[1:0] in_b,

    input wire out_pixclk,
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

localparam BORDER_R = 4'b0000;
localparam BORDER_G = 4'b0000;
localparam BORDER_B = 4'b0000;

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
localparam FIFO_ENTRY_W = 8;
localparam FIFO_ADDR_W = $clog2(IN_WIDTH-1);

// Two fifos with IN_WIDTH entries of width FIFO_ENTRY_W
reg[FIFO_ENTRY_W-1 : 0] linebuf[0 : 1][0 : IN_WIDTH-1];
reg line_in_parity;

reg[FIFO_ADDR_W-1 : 0] in_ptr, out_ptr;

reg out_of_reset;
reg[$clog2(OUT_HTOTAL)-1:0] out_hcount;
reg[$clog2(OUT_VTOTAL)-1:0] out_vcount;
reg line_out_parity;
reg pix_rep_count, line_rep_count;

wire hblk, vblk, cmpblk;
wire hborder, vborder, cmpborder;

// Input Handler
always @(posedge in_pixclk, rst_n)
begin
    if(rst_n == 1'b0) begin
        in_ptr <= 0;
        line_in_parity <= 0;
    end else if(in_valid == 1'b1) begin
        linebuf[line_in_parity][in_ptr] <= {in_b, in_g, in_r};

        // Inc fifo ptr
        if(in_ptr == IN_WIDTH - 1) begin
            // Reset ptr and choose next fifo
            in_ptr <= 0;
            line_in_parity <= ~line_in_parity;
        end else begin
            // Only inc ptr
            in_ptr <= in_ptr + 1;
        end
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
//                        (out_vcount < BORDER_HEIGHT)
//                   ||  (out_vcount >= BORDER_HEIGHT + 2*IN_HEIGHT)
                    out_vcount >= OUT_HEIGHT                        // For testing, no left border, double right border
                 );
assign cmpborder = hborder | vborder;


always @(posedge out_pixclk, rst_n)
begin
    if(rst_n == 1'b0) begin
        out_of_reset <= 1'b1;
        out_hcount <= 0;
        out_vcount <= 0;

        out_ptr <= 0;
        pix_rep_count <= 0;
        line_rep_count <= 0;
        line_out_parity <= 0;

        out_r <= 0;
        out_g <= 0;
        out_b <= 0;
        hsync <= ~HSYNC_ACTIVE;
        vsync <= ~VSYNC_ACTIVE;
    end else if(out_of_reset == 1'b1) begin
        // Stagger output so input a line ahead
        if(line_in_parity == 1'b1) begin
            out_of_reset <= 1'b0;
            line_out_parity <= ~line_in_parity;
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
            out_r <= BORDER_R;
            out_g <= BORDER_G;
            out_b <= BORDER_B;
        end else begin
            out_r <= {linebuf[line_out_parity][out_ptr][2:0], 1'b0};
            out_g <= {linebuf[line_out_parity][out_ptr][5:3], 1'b0};
            out_b <= {linebuf[line_out_parity][out_ptr][7:6], 2'b00};
        end

        // Handle pix/line doubler
        if(~cmpblk && ~cmpborder) begin
            pix_rep_count <= ~pix_rep_count;
            
            // Handle out_ptr
            if(pix_rep_count == 1'b1) begin
                // Inc out ptr
                if(out_ptr == IN_WIDTH - 1) begin
                    out_ptr <= 0;
                end else begin
                    out_ptr <= out_ptr + 1;
                end
            end

            // Handle line_rep_count
            if(pix_rep_count == 1'b1
            && out_ptr == IN_WIDTH - 1) begin
                line_rep_count <= ~line_rep_count;
            end

            // Handle line_out_parity
            if(pix_rep_count == 1'b1
            && out_ptr == IN_WIDTH - 1
            && line_rep_count == 1'b1) begin
                line_out_parity <= ~line_out_parity;
            end
        end else begin
            // TODO: Necessary?
            //pix_rep_count <= 0;
            //out_ptr <= 0;
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
