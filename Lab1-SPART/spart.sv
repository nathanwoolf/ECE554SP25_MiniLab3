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

always_ff @(posedge clk, posedge rst)begin
	if(rst)begin
	  rx_clr <= 1'b1;
	  start_transmit <= 1'b0;
	  transmit_data <= '0;
	  tx_rst <= 1'b1;
	end
	else if(iocs & (ioaddr == 0))begin
	  case(iorw)
	    1'b1 : begin
		ld_dbus <= 1'b1;
		rx_clr <= 1'b1;
	    end
	    1'b0 : begin
		transmit_data <= databus;
		start_transmit <= 1'b1;
	    end
	  endcase
	end
	else begin
	  start_transmit <= 1'b0;
	  rx_clr <= 1'b0;
	  ld_dbus <= 1'b0;
	  tx_rst <= 1'b0;
	end
end


assign databus = (ld_dbus) ? receive_data : 8'hz;
assign tbr = tx_done | tx_rst;
endmodule
