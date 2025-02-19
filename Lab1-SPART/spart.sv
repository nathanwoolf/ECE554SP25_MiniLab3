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
logic rx_clr, start_transmit, ld_dbus, tx_done, tx_rst;
logic [7:0] transmit_data, receive_data;

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

UART data_transfer(
	.clk(clk),
	.rst_n(!rst),
	.RX(rxd),
	.TX(txd),
	.rx_rdy(rda),
	.clr_rx_rdy(rx_clr),
	.rx_data(receive_data),
	.trmt(start_transmit),
	.tx_data(transmit_data),
	.tx_done(tx_done),
	.baud_rate(div_buf));

// baud counter for baud rate generator
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        baud_cnt <= '0;
    else if (rx & init|baud_en) 
        baud_cnt <= (init) ? (div_buf >> 1) : div_buf;
    else if (tx & init|baud_en)
        baud_cnt <= div_buf; 
    else if (tx|rx)
        baud_cnt <= baud_cnt - 1;    
end

assign baud_en = (baud_cnt == 0) ? 1 : 0;

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

logic br_change;

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
    tx_rdy = 1'b0;
    rx_done = 1'b0; 
    tx_done = 1'b0;
    br_change = 1'b1;
    next_state = state;
    case (state)
        IDLE : begin
            if (ioaddr == 2'b00 & iocs & !iorw) begin 
                init = 1'b1;
                next_state = TX;
            end
            else if (ioaddr == 2'b00 & iocs & iorw) 
                next_state = RX_WAIT;
            tx_rdy = 1'b1;
        end

        TX : begin
            if (ioaddr !== 2'b00) begin 
                br_change = 1'b1;
                next_state = IDLE;
            end
            else if (bit_cnt == 10) next_state = IDLE;
            else tx = 1'b1;
        end

        RX_WAIT : begin
            if (!rxd_ff) begin
                init = 1'b1;
                next_state = RX;
            end
            else if (ioaddr !== 2'b00) next_state = IDLE;
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
    else if (br_change) 
        tx_shift_reg <= 9'h1FF;
    else if (init) 
        tx_shift_reg <= {databus, 1'b0};       //appending zero for start signal to remote device
    else if (tx & baud_en) begin
        tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};
    end
end

assign txd = tx_shift_reg[0];

// shift reg for rx
always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        rx_shift_reg <= 9'h1FF;
    else if (rx & baud_en) begin
        rx_shift_reg <= {rxd_dff, rx_shift_reg[8:1]};
    end
end

assign databus = (rx_done) ? rx_shift_reg[7:0] : 8'hzz;

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin 
        tbr <= 1'b0; 
        rda <= 1'b0;
    end
    else if (tx_done | tx_rdy) tbr <= 1'b1;
    else if (rx_done) rda <= 1'b1;
end

assign databus = (ld_dbus) ? receive_data : 8'hz;
assign tbr = tx_done | tx_rst;
endmodule
