// SPDX-License-Identifier: GPL-3.0-or-later
// Graphics ROMs in SDRAM (MiSTer only). The six 27C010 are stored as 16-bit
// words: word w holds byte w of the upper bank (15-8) and of the lower bank
// (7-0). A stamp row is two consecutive words, read as one burst and handed
// to the playfield or the motion object reader as {word 1, word 0}. The
// playfield is served first; it has a deadline every eight pixels.
//
// Three of the four socket pairs are fitted: stamps 6000-7FFF read as all
// ones, an undriven data bus, which is pen 0 after the inversion.
//
// Download words are written one at a time; dl_busy holds the stream.
module offtwall_gfx_mem(
    input  wire        clk,
    input  wire        reset,
    // download
    input  wire        dl_wr,       // held until dl_ack
    input  wire [18:0] dl_addr,     // word address
    input  wire [15:0] dl_data,
    output reg         dl_ack,
    // readers
    input  wire        pf_req,
    input  wire [17:0] pf_addr,     // stamp (17-3), row (2-0)
    output reg         pf_ack,
    output reg  [31:0] pf_row,
    input  wire        mo_req,
    input  wire [17:0] mo_addr,
    output reg         mo_ack,
    output reg  [31:0] mo_row,
    // SDRAM controller
    output reg         sd_req,
    output reg         sd_we,
    output reg  [23:0] sd_addr,
    output reg  [15:0] sd_wdata,
    output wire  [2:0] sd_blen,
    input  wire        sd_ready,
    input  wire        sd_valid,
    input  wire [15:0] sd_rdata,
    output wire        rfsh_ok,
    output wire        idle
);
    localparam logic [14:0] STAMPS = 15'h6000;
    typedef enum logic [2:0] {IDLE, WRITE, WAIT_WRITE, READ0, READ1, DONE} state_t;
    state_t state;
    reg        for_mo;
    reg [15:0] first;
    assign sd_blen = 3'd1;
    assign rfsh_ok = 1'b1;
    assign idle    = state == IDLE && !dl_wr;

    // A request is taken once: the reader drops it the clk after the answer.
    wire pf_new = pf_req && !pf_ack;
    wire mo_new = mo_req && !mo_ack;
    always @(posedge clk) begin
        sd_req <= 1'b0;
        dl_ack <= 1'b0;
        pf_ack <= 1'b0;
        mo_ack <= 1'b0;
        if (reset) begin
            state <= IDLE;
        end else case (state)
            IDLE: if (sd_ready && !sd_req) begin
                if (dl_wr && !dl_ack) begin
                    sd_req   <= 1'b1;
                    sd_we    <= 1'b1;
                    sd_addr  <= {5'd0, dl_addr};
                    sd_wdata <= dl_data;
                    state    <= WRITE;
                end else if (pf_new || mo_new) begin
                    for_mo <= !pf_new;
                    if ((pf_new ? pf_addr[17:3] : mo_addr[17:3]) >= STAMPS) begin
                        if (pf_new) begin pf_row <= 32'hFFFFFFFF; pf_ack <= 1'b1; end
                        else        begin mo_row <= 32'hFFFFFFFF; mo_ack <= 1'b1; end
                        state <= DONE;
                    end else begin
                        sd_req  <= 1'b1;
                        sd_we   <= 1'b0;
                        sd_addr <= {5'd0, pf_new ? pf_addr : mo_addr, 1'b0};
                        state   <= READ0;
                    end
                end
            end
            // The controller drops ready while it works on the request.
            WRITE:      if (!sd_ready) state <= WAIT_WRITE;
            WAIT_WRITE: if (sd_ready) begin dl_ack <= 1'b1; state <= DONE; end
            READ0: if (sd_valid) begin first <= sd_rdata; state <= READ1; end
            READ1: if (sd_valid) begin
                if (for_mo) begin mo_row <= {sd_rdata, first}; mo_ack <= 1'b1; end
                else        begin pf_row <= {sd_rdata, first}; pf_ack <= 1'b1; end
                state <= DONE;
            end
            DONE: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule
