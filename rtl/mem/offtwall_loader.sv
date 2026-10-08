// SPDX-License-Identifier: GPL-3.0-or-later
// Routes the ROM download stream (MiSTer only). Stream layout, in bytes:
//   000000-03FFFF  program ROMs, high byte first
//   040000-04FFFF  sound program ROM
//   050000-10FFFF  graphics, lower-bank byte then upper-bank byte of each word
//   110000-1107FF  EEPROM factory image
// Program, sound and EEPROM bytes go straight to their memories. Graphics
// bytes are paired into words for offtwall_gfx_mem; busy holds the stream
// while a word is being written.
module offtwall_loader(
    input  wire        clk,
    input  wire        reset,
    input  wire        wr,          // one clk per byte
    input  wire [20:0] addr,
    input  wire  [7:0] data,
    output wire        busy,
    output wire        prog_we,
    output wire        snd_we,
    output wire        nv_we,
    output wire        nv_last,     // the byte that completes the image
    output reg         gfx_wr,      // held until gfx_ack
    output reg  [18:0] gfx_addr,
    output reg  [15:0] gfx_data,
    input  wire        gfx_ack
);
    localparam logic [20:0] SND = 21'h040000, GFX = 21'h050000, NV = 21'h110000,
                            END = 21'h110800;
    assign prog_we = wr && addr < SND;
    assign snd_we  = wr && addr >= SND && addr < GFX;
    assign nv_we   = wr && addr >= NV && addr < END;
    assign nv_last = nv_we && addr == END - 21'd1;
    wire        is_gfx = wr && addr >= GFX && addr < NV;
    wire [20:0] offset = addr - GFX;

    reg [7:0] low;
    always @(posedge clk) begin
        if (reset) begin
            gfx_wr <= 1'b0;
        end else begin
            if (gfx_ack) gfx_wr <= 1'b0;
            if (is_gfx && !offset[0]) low <= data;
            if (is_gfx && offset[0]) begin
                gfx_wr   <= 1'b1;
                gfx_addr <= offset[19:1];
                gfx_data <= {data, low};
            end
        end
    end
    assign busy = gfx_wr || (is_gfx && offset[0]);

    wire unused = &{1'b0, offset[20]};
endmodule
