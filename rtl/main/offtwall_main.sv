// SPDX-License-Identifier: GPL-3.0-or-later
// The main processor side of the game board: 68000, program ROM and its bank
// device, address decode, wait states, EEPROM, watchdog, interrupts and the
// I/O block. The video system and the sound board connect through ports.
module offtwall_main #(
    parameter bit CPU_14M = 1'b1,          // processor clock: 14.318 or 7.159 MHz
    parameter int CLK_HZ  = 57272727,
    parameter int EEPROM_WRITE_CYCLES = CLK_HZ / 100
)(
    input  wire        clk,
    input  wire        init_reset,         // FPGA start-up and ROM download
    input  wire        ce_14m,
    input  wire        ce_7m,
    input  wire        ce_1h,

    // program ROM download
    input  wire        dl_we,
    input  wire [17:0] dl_addr,
    input  wire  [7:0] dl_data,

    // video system
    input  wire        vblank,
    input  wire        vint_n,
    input  wire        vdtack_n,
    input  wire [15:0] video_rdata,
    output wire        video_n,

    // sound board mailbox
    input  wire        audfull_n,
    input  wire        audirq_n,
    input  wire  [7:0] snd_rdata,
    output wire        scom_rd_n,
    output wire        scom_wr_n,
    output wire        sndres_n,

    // cabinet
    input  wire  [7:0] p1_n, p2_n, p3_n, p4_n,
    input  wire  [3:0] service_n,
    input  wire  [3:0] coin_n,
    input  wire        self_test_n,
    input  wire        vup_n,
    input  wire        vdn_n,
    input  wire        opt_sw,
    input  wire        leta_fitted,
    input  wire        hold_n,             // decoder GAL pin 1
    output wire  [3:0] coin_counter,

    // EEPROM image load and save
    input  wire        nv_load_we,
    input  wire [10:0] nv_load_addr,
    input  wire  [7:0] nv_load_data,
    input  wire        nv_seed_we,
    input  wire        nv_load_end,
    input  wire [10:0] nv_dump_addr,
    output wire  [7:0] nv_dump_data,
    output wire        nv_write_accepted,

    // the bus, for the video system and for observation
    output wire [23:1] a,
    output wire [15:0] wdata,
    output wire [15:0] rdata,
    output wire        as_n,
    output wire        uds_n,
    output wire        lds_n,
    output wire        rw,
    output wire        dtack_n,
    output wire  [2:0] fc,
    output wire  [2:0] ipl_n,
    output wire        sysres_n,
    output wire        ce_cpu,
    output wire  [1:0] bank               // program ROM bank, for observation
);
    // ---- reset and watchdog ----
    wire wdog_n;
    wire [3:0] wdog_count;
    offtwall_watchdog #(.CLK_HZ(CLK_HZ)) u_watchdog(.clk(clk), .ext_reset(init_reset),
        .vblank(vblank), .wdog_n(wdog_n), .sysres_n(sysres_n), .count(wdog_count));

    // ---- interrupts: level 4 video, level 6 sound, both autovectored ----
    assign ipl_n = {vint_n & audirq_n, audirq_n, 1'b1};
    wire vpa_n = !(!as_n && fc == 3'b111);

    // ---- processor ----
    offtwall_cpu #(.CPU_14M(CPU_14M)) u_cpu(.clk(clk), .ce_14m(ce_14m), .ce_7m(ce_7m),
        .reset(!sysres_n), .ipl_n(ipl_n), .a(a), .wdata(wdata), .rdata(rdata),
        .as_n(as_n), .uds_n(uds_n), .lds_n(lds_n), .rw(rw), .dtack_n(dtack_n),
        .vpa_n(vpa_n), .fc(fc), .ce_cpu(ce_cpu));

    // ---- decode and wait states ----
    wire rom0_n, romx_n, e1_n, wait_n, vrwait_n, eeprom_n, cio_n, video_sel_n;
    offtwall_decode u_decode(.a(a[21:15]), .as_n(as_n), .hold_n(hold_n), .vdtack_n(vdtack_n),
        .rom0_n(rom0_n), .romx_n(romx_n), .e1_n(e1_n), .wait_n(wait_n), .vrwait_n(vrwait_n),
        .eeprom_n(eeprom_n), .cio_n(cio_n), .wdog_n(wdog_n), .video_n(video_sel_n));
    // The video system must not answer an interrupt acknowledge cycle.
    assign video_n = video_sel_n || fc == 3'b111;
    wire [3:0] wait_count;
    offtwall_dtack u_dtack(.clk(clk), .ce_cpu(ce_cpu), .as_n(as_n), .wait_n(wait_n),
        .vrwait_n(vrwait_n), .vpa_n(vpa_n), .dtack_n(dtack_n), .count(wait_count));

    // ---- program ROM and its bank device ----
    // The bank device sees one event per ROM bus cycle: /AS falling with a
    // ROM address on the bus.
    reg as_q;
    always @(posedge clk) as_q <= as_n;
    wire rom_sel   = !as_n && !rom0_n && fc != 3'b111;
    wire rom_cycle = rom_sel && as_q;
    wire [14:13] ra;
    reg  [14:13] ra_q;
    offtwall_sloop u_sloop(.clk(clk), .reset(init_reset), .rom_cycle(rom_cycle),
        .a(a[17:1]), .ra(ra));
    assign bank = ra - a[14:13];
    // The bank is settled one clk after the cycle starts; hold the ROM
    // address until then.
    always @(posedge clk) ra_q <= ra;
    wire [15:0] rom_q;
    offtwall_prog_rom u_rom(.clk(clk), .addr({a[17:15], ra_q, a[12:1]}), .q(rom_q),
        .dl_we(dl_we), .dl_addr(dl_addr), .dl_data(dl_data));

    // ---- write data and address held past the end of /AS ----
    reg [15:0] wdata_q;
    reg        lds_q, ee_in_window;
    reg [10:0] ee_addr;
    wire wl_n = !(!as_n && !rw && !lds_n);
    always @(posedge clk) begin
        lds_q <= wl_n;
        if (!as_n) wdata_q <= rw ? 16'hFFFF : wdata;
        if (!wl_n) ee_in_window <= !eeprom_n;
        if (!eeprom_n) ee_addr <= a[11:1];
    end
    wire wl_rise = wl_n && !lds_q;

    // ---- I/O block ----
    wire unlock_n;
    wire [15:0] io_rdata, io_rdrive;
    wire leta_res;
    offtwall_inputs u_inputs(.clk(clk), .sysres_n(sysres_n), .as_n(as_n), .cio_n(cio_n),
        .a(a[6:1]), .wdata(wdata_q), .p1_n(p1_n), .p2_n(p2_n), .p3_n(p3_n), .p4_n(p4_n),
        .service_n(service_n), .coin_n(coin_n), .vblank_n(!vblank),
        .self_test_n(self_test_n), .audfull_n(audfull_n), .audirq_n(audirq_n),
        .vup_n(vup_n), .vdn_n(vdn_n), .opt_sw(opt_sw), .leta_fitted(leta_fitted),
        .ce_1h(ce_1h), .scom_rd_n(scom_rd_n), .scom_wr_n(scom_wr_n), .unlock_n(unlock_n),
        .rdata(io_rdata), .rdrive(io_rdrive), .coin_counter(coin_counter),
        .sndres_n(sndres_n), .leta_res(leta_res));

    // ---- EEPROM ----
    wire [7:0] ee_q;
    wire ee_busy, ee_oe_n, ee_unlocked;
    offtwall_eeprom_28c16 #(.CLK_HZ(CLK_HZ), .WRITE_CYCLES(EEPROM_WRITE_CYCLES)) u_eeprom(
        .clk(clk), .init_reset(init_reset), .reset(!sysres_n), .unlock(!unlock_n),
        .any_write(wl_rise), .cpu_we(wl_rise && ee_in_window), .cpu_addr(ee_addr),
        .cpu_wdata(wdata_q[7:0]), .cpu_rdata(ee_q), .busy(ee_busy), .oe_n(ee_oe_n),
        .unlocked(ee_unlocked), .write_accepted(nv_write_accepted),
        .load_we(nv_load_we), .load_addr(nv_load_addr), .load_data(nv_load_data),
        .seed_we(nv_seed_we), .load_end(nv_load_end),
        .dump_addr(nv_dump_addr), .dump_data(nv_dump_data));

    // ---- read data: anything not driven reads as ones ----
    assign rdata = rom_sel                ? rom_q :
                   !video_n               ? video_rdata :
                   (!eeprom_n && rw)      ? {8'hFF, ee_q} :
                   (!scom_rd_n && rw)     ? {8'hFF, snd_rdata} :
                   !cio_n                 ? (io_rdata | ~io_rdrive) : 16'hFFFF;

    /* verilator lint_off UNUSEDSIGNAL */
    wire unused = &{1'b0, romx_n, e1_n, wdog_count, wait_count, leta_res, ee_busy, ee_oe_n,
                    ee_unlocked, a[23:22], uds_n};
    /* verilator lint_on UNUSEDSIGNAL */
endmodule
