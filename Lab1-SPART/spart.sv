//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:   
// Design Name: 
// Module Name:    spart 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module spart(
    input clk,
    input rst,
    input iocs,
    input iorw,         // 1: spart to driver       0: driver to spart
    output logic rda,
    output logic tbr,
    input [1:0] ioaddr,
    inout [7:0] databus,
    output txd,
    input rxd);

//  creating baud rate generator

//  DIP Setting to Baud Rate mapping (comes in through I/O address)
//  00 -> 4800  ->  650 -> 0x28A
//  01 -> 9600  ->  325 -> 0x145
//  10 -> 19200 ->  162 -> 0xA2
//  11 -> 38400 ->  80  -> 0x50

//  IOADDR bit mappings
//  00 -> Tx buffer (R/W = 0) : Rx buffer (R/W = 1)
//  01 -> Status register (R/W = 1) **IGNORED**
//  10 -> DB (low) division buffer
//  11 -> DB (high) division buffer

// division buffer for baud rate generator from DRIVER

logic [15:0] div_buf;
always_ff @(posedge clk, posedge rst) begin 
    if (rst) begin 
        div_buf <= 16'b0;
    end
    else if (iocs & !iorw) begin
        case (ioaddr)
            2'b10 : div_buf[7:0] <= databus;
            2'b11 : div_buf[15:8] <= databus;
        endcase
    end
end

// internal signals for SPART Tx and Rx
logic [15:0] baud_cnt;
logic baud_en;
logic tx, rx, init, rxd_ff, rxd_dff, tx_done, rx_done, shift;
logic [8:0] tx_shift_reg, rx_shift_reg;
logic [3:0] bit_cnt;

// baud counter for baud rate generator
always_ff @(posedge clk, posedge rst) begin
    if (init|baud_en) 
        baud_cnt <= div_buf;
    else if (tx|rx)
        baud_cnt <= baud_cnt - 1;    
end

assign baud_en = (baud_cnt === 0) ? 1 : 0;

// bit count register for Tx and Rx
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        bit_cnt <= 4'b0;
    else if (tx|rx) begin
        if (baud_en) 
            bit_cnt <= bit_cnt + 1;
    end
end 

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin 
        rxd_ff <= 1'b1;
        rxd_dff <= 1'b1;
    end
    else begin
        rxd_ff <= rxd;
        rxd_dff <= rxd_ff;
    end
end

// ************************** STATE MACHINE **************************
typedef enum reg [1:0] {IDLE, TX, RX_WAIT, RX} state_t;
state_t state, next_state;

always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        state <= IDLE;
    else
        state <= next_state;
end

always_comb begin
    tx = 1'b0; 
    rx = 1'b0;
    init = 1'b0; 
    next_state = state;
    case (state)
        IDLE : begin
            if (ioaddr == 2'b00 & iocs & !iorw) begin 
                init = 1'b1;
                next_state = TX;
            end
            else if (ioaddr == 2'b00 & iocs & iorw) 
                next_state = RX_WAIT;
        end

        TX : begin
            if (bit_cnt == 10) next_state = IDLE;
            else tx = 1'b1;
        end

        RX_WAIT : begin
            if (!rxd_ff) begin
                init = 1'b1;
                next_state = RX;
            end
        end

        RX : begin
            if (bit_cnt == 10) begin 
                rx_done = 1'b1;
                next_state = IDLE;
            end
            else rx = 1'b1;
        end
    endcase
end

// shift reg for tx 
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        tx_shift_reg <= 9'h1FF;
    else if (init) 
        tx_shift_reg <= {databus, 1'b0};       //appending zero for start signal to remote device
    else if (tx & shift) begin
        tx_shift_reg <= {tx_shift_reg[7:0], 1'b1};
    end
end

assign txd = tx_shift_reg[0];

// shift reg for rx
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        rx_shift_reg <= 9'h1FF;
    else if (rx & shift) begin
        rx_shift_reg <= {rxd_dff, rx_shift_reg[8:1]};
    end
end

assign databus = rx_shift_reg[7:0];

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
        tx_done <= 1'b0;
        rx_done <= 1'b0;
    end
    else if (init) begin 
        tx_done <= 1'b0;
        rx_done <= 1'b0;
    end 
    else if (tx_done) tbr <= 1'b1;
    else if (rx_done) rda <= 1'b1;
end

endmodule
