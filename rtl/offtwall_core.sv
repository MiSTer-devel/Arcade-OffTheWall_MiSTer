// SPDX-License-Identifier: GPL-3.0-or-later
// Off the Wall: the game board, the JSA III sound board and the memories that
// stand in for their ROMs. Everything runs on clk_sys = 57.272727 MHz with
// clock enables. Switch inputs are as the board sees them: 0 = closed.
module offtwall_core #(
    parameter bit CPU_14M = 1'b1,
    parameter int EEPROM_WRITE_CYCLES = 57272727 / 100
)(
    input  wire        clk_sys,
    input  wire        init_reset,     // PLL not locked: also restarts the SDRAM
    input  wire        reset,          // user reset

    // MiSTer file channels: index 0 is the ROM stream (layout in
    // offtwall_loader.sv), index 2 the EEPROM save file
    input  wire        ioctl_download,
    input  wire        ioctl_wr,
    input  wire [26:0] ioctl_addr,
    input  wire  [7:0] ioctl_dout,
    input  wire [15:0] ioctl_index,
    output wire        ioctl_wait,
    input  wire        ioctl_upload,
    output wire        ioctl_upload_req,
    output wire  [7:0] ioctl_upload_index,
    output wire  [7:0] ioctl_din,
    output reg         rom_loaded,

    // cabinet
    input  wire  [7:0] p1_n, p2_n, p3_n, p4_n,
    input  wire  [3:0] service_n,
    input  wire  [3:0] coin_n,         // game board coin header
    input  wire        self_test_n,
    input  wire        vup_n, vdn_n,
    input  wire        opt_sw,
    input  wire        leta_fitted,
    input  wire        snd_coin_l, snd_coin_r, snd_service, snd_tilt,   // 1 = closed
    output wire  [3:0] coin_counter,
    output wire        snd_cctr1, snd_cctr2,

    // picture
    output wire        ce_pix,
    output wire  [7:0] vga_r, vga_g, vga_b,
    output wire        hsync, vsync, hblank, vblank,
    output wire [10:0] pix_index,
    output wire [15:0] pix_colour,

    // sound
    output wire signed [15:0] audio,

    // diagnostics
    output wire        gfx_late, eof_late,
    output wire  [8:0] beam_h, beam_v,
    output wire [23:1] cpu_a,
    output wire [15:0] cpu_wdata, cpu_rdata,
    output wire        cpu_as_n, cpu_uds_n, cpu_lds_n, cpu_rw, cpu_dtack_n,

    inout  wire [15:0] SDRAM_DQ,
    output wire [12:0] SDRAM_A,
    output wire  [1:0] SDRAM_BA,
    output wire        SDRAM_DQML, SDRAM_DQMH, SDRAM_CKE, SDRAM_nCS,
    output wire        SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE
);
    localparam logic [26:0] STREAM_BYTES = 27'h110800;

    // ---- download ----
    wire downloading = ioctl_download && ioctl_index == 16'd0;
    wire ld_wr = downloading && ioctl_wr && ioctl_addr < STREAM_BYTES;
    wire ld_busy, prog_we, snd_we, seed_we, seed_last, gfx_wr, gfx_ack;
    wire [18:0] gfx_addr;
    wire [15:0] gfx_data;
    offtwall_loader u_loader(.clk(clk_sys), .reset(init_reset), .wr(ld_wr), .addr(ioctl_addr[20:0]),
        .data(ioctl_dout), .busy(ld_busy), .prog_we(prog_we), .snd_we(snd_we),
        .nv_we(seed_we), .nv_last(seed_last),
        .gfx_wr(gfx_wr), .gfx_addr(gfx_addr), .gfx_data(gfx_data), .gfx_ack(gfx_ack));

    wire        pf_req, pf_ack, mo_req, mo_ack;
    wire [17:0] pf_addr, mo_addr;
    wire [31:0] pf_row, mo_row;
    wire        sd_req, sd_we, sd_ready, sd_valid, rfsh_ok, mem_idle;
    wire [23:0] sd_addr;
    wire [15:0] sd_wdata, sd_rdata;
    wire  [2:0] sd_blen;
    offtwall_gfx_mem u_gfx(.clk(clk_sys), .reset(init_reset),
        .dl_wr(gfx_wr), .dl_addr(gfx_addr), .dl_data(gfx_data), .dl_ack(gfx_ack),
        .pf_req(pf_req), .pf_addr(pf_addr), .pf_ack(pf_ack), .pf_row(pf_row),
        .mo_req(mo_req), .mo_addr(mo_addr), .mo_ack(mo_ack), .mo_row(mo_row),
        .sd_req(sd_req), .sd_we(sd_we), .sd_addr(sd_addr), .sd_wdata(sd_wdata),
        .sd_blen(sd_blen), .sd_ready(sd_ready), .sd_valid(sd_valid), .sd_rdata(sd_rdata),
        .rfsh_ok(rfsh_ok), .idle(mem_idle));
    offtwall_sdram u_sdram(.clk(clk_sys), .reset(init_reset), .addr(sd_addr),
        .wdata(sd_wdata), .we(sd_we), .blen(sd_blen), .req(sd_req), .rdata(sd_rdata),
        .valid(sd_valid), .ready(sd_ready), .rfsh_ok(rfsh_ok),
        .SDRAM_DQ(SDRAM_DQ), .SDRAM_A(SDRAM_A), .SDRAM_BA(SDRAM_BA),
        .SDRAM_DQML(SDRAM_DQML), .SDRAM_DQMH(SDRAM_DQMH), .SDRAM_CKE(SDRAM_CKE),
        .SDRAM_nCS(SDRAM_nCS), .SDRAM_nRAS(SDRAM_nRAS), .SDRAM_nCAS(SDRAM_nCAS),
        .SDRAM_nWE(SDRAM_nWE));
    assign ioctl_wait = ld_busy || !sd_ready;

    // The game starts only after one complete, in-order download.
    reg [26:0] received;
    reg        was_download, bad_download;
    always @(posedge clk_sys) begin
        if (init_reset) begin
            received <= 27'd0; was_download <= 1'b0; bad_download <= 1'b0; rom_loaded <= 1'b0;
        end else begin
            was_download <= downloading;
            if (downloading && !was_download) begin
                received <= 27'd0; bad_download <= 1'b0; rom_loaded <= 1'b0;
            end
            if (downloading && ioctl_wr) begin
                if (ioctl_addr != (was_download ? received : 27'd0) || ioctl_addr >= STREAM_BYTES)
                    bad_download <= 1'b1;
                received <= ioctl_addr + 27'd1;
            end
            if (!downloading && received == STREAM_BYTES && !bad_download && !ld_busy
                && mem_idle) rom_loaded <= 1'b1;
        end
    end
    wire hold = init_reset || reset || downloading || !rom_loaded;

    // ---- EEPROM save file and factory image ----
    wire        nv_load_we, nv_seed_we, nv_load_end, nv_write_accepted;
    wire [10:0] nv_load_addr, nv_dump_addr;
    wire  [7:0] nv_load_data, nv_dump_data;
    offtwall_nvram_io u_nvram(.clk(clk_sys), .init_reset(init_reset),
        .write_accepted(nv_write_accepted),
        .ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_addr(ioctl_addr),
        .ioctl_dout(ioctl_dout), .ioctl_index(ioctl_index), .ioctl_upload(ioctl_upload),
        .load_we(nv_load_we), .load_addr(nv_load_addr), .load_data(nv_load_data),
        .seed_we(nv_seed_we), .load_end(nv_load_end),
        .dump_addr(nv_dump_addr), .dump_data(nv_dump_data),
        .ioctl_upload_req(ioctl_upload_req), .ioctl_upload_index(ioctl_upload_index),
        .ioctl_din(ioctl_din));

    // ---- clocks ----
    wire ce_14m, ce_7m, ce_3m58, ce_1m79;
    offtwall_clocks u_clocks(.clk_sys(clk_sys), .reset(init_reset), .ce_14m(ce_14m),
        .ce_7m(ce_7m), .ce_3m58(ce_3m58), .ce_1m79(ce_1m79));

    // ---- game board ----
    wire        vblank_board, hblank_board, vint_n, vdtack_n, video_n;
    wire [15:0] video_rdata;
    wire        audfull_n, audirq_n, scom_rd_n, scom_wr_n, sndres_n;
    wire  [7:0] snd_rdata;
    wire        sysres_n, ce_cpu;
    wire        uds_n = cpu_uds_n, lds_n = cpu_lds_n, rw = cpu_rw;
    wire  [2:0] fc, ipl_n;
    wire  [1:0] bank;
    offtwall_main #(.CPU_14M(CPU_14M), .EEPROM_WRITE_CYCLES(EEPROM_WRITE_CYCLES)) u_main(
        .clk(clk_sys), .init_reset(hold), .ce_14m(ce_14m), .ce_7m(ce_7m), .ce_1h(ce_3m58),
        .dl_we(prog_we), .dl_addr(ioctl_addr[17:0]), .dl_data(ioctl_dout),
        .vblank(vblank_board), .vint_n(vint_n), .vdtack_n(vdtack_n),
        .video_rdata(video_rdata), .video_n(video_n),
        .audfull_n(audfull_n), .audirq_n(audirq_n), .snd_rdata(snd_rdata),
        .scom_rd_n(scom_rd_n), .scom_wr_n(scom_wr_n), .sndres_n(sndres_n),
        .p1_n(p1_n), .p2_n(p2_n), .p3_n(p3_n), .p4_n(p4_n),
        .service_n(service_n), .coin_n(coin_n), .self_test_n(self_test_n),
        .vup_n(vup_n), .vdn_n(vdn_n), .opt_sw(opt_sw), .leta_fitted(leta_fitted),
        .hold_n(1'b1), .coin_counter(coin_counter),
        .nv_load_we(nv_load_we), .nv_load_addr(nv_load_addr), .nv_load_data(nv_load_data),
        .nv_seed_we(nv_seed_we), .nv_load_end(nv_load_end),
        .nv_dump_addr(nv_dump_addr), .nv_dump_data(nv_dump_data),
        .nv_write_accepted(nv_write_accepted),
        .a(cpu_a), .wdata(cpu_wdata), .rdata(cpu_rdata), .as_n(cpu_as_n),
        .uds_n(cpu_uds_n), .lds_n(cpu_lds_n), .rw(cpu_rw), .dtack_n(cpu_dtack_n), .fc(fc), .ipl_n(ipl_n),
        .sysres_n(sysres_n), .ce_cpu(ce_cpu), .bank(bank));

    offtwall_video u_video(.clk(clk_sys), .reset(hold), .ce_14m(ce_14m),
        .select_n(video_n), .rw(rw), .uds_n(uds_n), .lds_n(lds_n), .a(cpu_a[16:1]),
        .wdata(cpu_wdata), .rdata(video_rdata), .vdtack_n(vdtack_n), .vint_n(vint_n),
        .snap_wr(1'b0), .snap_cr(1'b0), .snap_a(15'd0), .snap_d(16'd0),
        .pf_req(pf_req), .pf_addr(pf_addr), .pf_ack(pf_ack), .pf_row(pf_row),
        .mo_req(mo_req), .mo_addr(mo_addr), .mo_ack(mo_ack), .mo_row(mo_row),
        .ce_pix(ce_pix), .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b),
        .hsync(hsync), .vsync(vsync), .hblank(hblank), .vblank(vblank),
        .pix_index(pix_index), .pix_colour(pix_colour), .hblank_board(hblank_board), .vblank_board(vblank_board),
        .beam_h(beam_h), .beam_v(beam_v), .gfx_late(gfx_late), .eof_late(eof_late));

    // ---- audio header ----
    // The command latch is clocked by the end of /SCOM-WR; the response flag
    // is cleared as soon as /SCOM-RD is asserted.
    reg       scom_wr_q, scom_rd_q;
    reg [7:0] scom_wdata;
    always @(posedge clk_sys) begin
        scom_wr_q <= scom_wr_n;
        scom_rd_q <= scom_rd_n;
        if (!scom_wr_n) scom_wdata <= cpu_wdata[7:0];
    end
    wire [15:0] snd_addr_nc;
    wire  [7:0] snd_dout_nc, snd_din_nc, snd_sel_nc;
    wire        snd_rnw_nc, snd_sync_nc, snd_o2_nc, snd_vol_nc, snd_irq_nc, snd_nmi_nc;
    wire        snd_ms4_nc, snd_clip_nc, cctr_or_nc;
    wire signed [15:0] audio_r_nc;
    offtwall_sound u_sound(.clk(clk_sys), .ce_3m58(ce_3m58), .ce_1m79(ce_1m79), .por(hold),
        .scom_wr(scom_wr_n && !scom_wr_q), .scom_wr_data(scom_wdata),
        .scom_rd(!scom_rd_n && scom_rd_q), .scom_rd_data(snd_rdata),
        .audirq_n(audirq_n), .audfull_n(audfull_n), .sndres(!sndres_n),
        .self_test(!self_test_n), .service(snd_service), .tilt(snd_tilt),
        .coin_l(snd_coin_l), .coin_r(snd_coin_r),
        .cctr1(snd_cctr1), .cctr2(snd_cctr2), .cctr_wired_or(cctr_or_nc),
        .rom_wr(snd_we), .rom_addr(ioctl_addr[15:0]), .rom_data(ioctl_dout),
        .audio_l(audio), .audio_r(audio_r_nc),
        .dbg_cpu_addr(snd_addr_nc), .dbg_cpu_dout(snd_dout_nc), .dbg_cpu_din(snd_din_nc),
        .dbg_cpu_rnw(snd_rnw_nc), .dbg_cpu_sync(snd_sync_nc), .dbg_o2(snd_o2_nc),
        .dbg_sel(snd_sel_nc), .dbg_sel_vol(snd_vol_nc), .dbg_irq_n(snd_irq_nc),
        .dbg_nmi_n(snd_nmi_nc), .dbg_ms4irq(snd_ms4_nc), .dbg_clipped(snd_clip_nc));

    wire unused = &{1'b0, seed_we, seed_last, hblank_board, fc, ipl_n, sysres_n,
                    ce_cpu, bank, ce_7m, snd_addr_nc, snd_dout_nc, snd_din_nc, snd_sel_nc,
                    snd_rnw_nc, snd_sync_nc, snd_o2_nc, snd_vol_nc, snd_irq_nc, snd_nmi_nc,
                    snd_ms4_nc, snd_clip_nc, cctr_or_nc, audio_r_nc};
endmodule
