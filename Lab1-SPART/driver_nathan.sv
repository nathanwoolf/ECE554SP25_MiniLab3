module driver_nathan (
    input clk,
    input rst,
    input [1:0] br_cfg,
    output iocs,
    output iorw,
    input rda,
    input tbr,
    output [1:0] ioaddr,
    inout [7:0] databus
); 

//  DIP Setting to Baud Rate mapping (comes in through I/O address)
//  00 -> 4800  ->  650 -> 0x28A
//  01 -> 9600  ->  325 -> 0x145
//  10 -> 19200 ->  162 -> 0xA2
//  11 -> 38400 ->  80  -> 0x50

//  IOADDR bit mappings
//  00 -> Tx buffer (R/W = 0) : Rx buffer (R/W = 1)
//  01 -> Status register (R/W = 1)
//  10 -> DB (low) division buffer
//  11 -> DB (high) division buffer

logic [15:0] baud_rate;
logic[7:0] read_data;
logic [1:0] br_cfg_prev;
logic rd_dbus, ld_dbus, ld_brt, ld_brb, br_change, br_change_wait, br_change_cons;

//Detect change in baud rate, update spart baud rate if change
always_ff@(posedge clk, posedge rst)begin
  if(rst)
    br_cfg_prev <= '0;
  else
    br_cfg_prev <= br_cfg;
end

assign br_change = (br_cfg !== br_cfg_prev) ? 1'b1 : 1'b0;

always_ff@(posedge clk, posedge rst)begin
    if(rst)
        br_change_cons <= 1'b0;
    else if (br_change)
        br_change_wait <= 1'b1;
    else if (br_change_cons)
        br_change_wait <= 1'b0;
end

//Select value stored in spart divisor buffer based on baud rate
always_ff@(posedge clk, posedge rst)begin
  if(rst)
    baud_rate <= '0;
  else begin
    case(br_cfg)
      2'b00: baud_rate <= 16'h028A;
      2'b01: baud_rate <= 16'h0145;
      2'b10: baud_rate <= 16'h00A2;
      2'b11: baud_rate <= 16'h0050;
    endcase
  end
end

//Read the data bus if data is available
always_ff@(posedge clk, posedge rst) begin
  if(rst)
    read_data <= '0;
  else if(rd_dbus)
    read_data <= databus;
end

//Load the databus with required data based on state
always @(*) begin
  if(ld_brt)
    databus <= baud_rate[15:8];
  if(ld_brb)
    databus <= baud_rate[7:0];
  if(ld_dbus)
    databus <= read_data;
end

// ************************** STATE MACHINE **************************
typedef enum reg [2:0] {DB_LOW, DB_HIGH, CMD_RX, RX_WAIT, CMD_TX, TX_WAIT} state_t;
state_t state, nxt_state;  

always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        state <= DB_HIGH;
    else
        state <= next_state;
end

always_comb begin
    iocs = 1'b0; 
    iorw = 1'b0;
    ioaddr = 2'b00;
    nxt_state = state; 
    
    case (state) 
        DB_HIGH : begin
            ld_brt = 1'b1;
            iocs = 1'b1;
            ioaddr = 2'b11;
            iorw = 1'b0;
            nxt_state = DB_LOW;
        end

        DB_LOW : begin
            ld_brb = 1'b1;
            iocs = 1'b1;
            ioaddr = 2'b10;
            iorw = 1'b0;
            nxt_state = CMD_RX;
        end

        CMD_RX : begin
            if (br_change_wait) 
                nxt_state = DB_HIGH;
            else begin
                iocs = 1'b1;
                ioaddr = 2'b00;
                iorw = 1'b1;
                nxt_state = RX_WAIT;
            end
        end

        RX_WAIT : begin
           if (rda) nxt_state = CMD_TX;
        end

        CMD_TX : begin
            if (tbr) begin
                iocs = 1'b1;
                ioaddr = 2'b00;
                iorw = 1'b0;
                nxt_state = TX_WAIT;
            end
        end

        TX_WAIT : begin
            if (tbr) nxt_state = CMD_RX;
        end
    endcase

end

endmodule