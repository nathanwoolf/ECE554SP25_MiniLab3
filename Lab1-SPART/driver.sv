module driver (
    input clk,
    input rst,
    input [1:0] br_cfg,
    output logic iocs,
    output logic iorw,
    input rda,
    input tbr,
    output logic [1:0] ioaddr,
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
  if(rst) begin
    br_cfg_prev <= '0;
  end
  else begin
    br_cfg_prev <= br_cfg;
  end
end

assign br_change = (br_cfg !== br_cfg_prev) ? 1'b1 : 1'b0;

always_ff@(posedge clk, posedge rst)begin
    if(rst)
        br_change_wait <= 1'b0;
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
      2'b00: baud_rate <= 16'h27A3;
      2'b01: baud_rate <= 16'h1458;
      2'b10: baud_rate <= 16'h0A2C;
      2'b11: baud_rate <= 16'h0516;
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

// ************************** STATE MACHINE **************************
typedef enum reg [2:0] {DUMMY, DB_LOW, DB_HIGH, CMD_RX, RX_WAIT, CMD_TX, TX_WAIT} state_t;
state_t state, nxt_state;  

always_ff @(posedge clk, posedge rst) begin
    if (rst) 
        state <= DUMMY;
    else
        state <= nxt_state;
end

always_comb begin
    iocs = 1'b0; 
    iorw = 1'b0;
    ioaddr = 2'b00;
    ld_brt = 1'b0;
    ld_brb = 1'b0; 
    rd_dbus = 0;
    ld_dbus = 0;
    br_change_cons = 1'b0;
    nxt_state = state; 
    
    case (state) 
        DUMMY: begin 
            nxt_state = DB_HIGH;
        end

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
            nxt_state = RX_WAIT;
        end

        RX_WAIT : begin
           iocs = 1'b1;
           ioaddr = 2'b00;
           iorw = 1'b1;
           if (rda) begin 
                rd_dbus = 1'b1;
                nxt_state = CMD_TX;
            end
            else if (br_change_wait) begin
                br_change_cons = 1'b1;
                nxt_state = DB_HIGH;
            end
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
            if (tbr) begin
                ld_dbus = 1'b1; 
                nxt_state = RX_WAIT;
            end
        end
    endcase
end

assign databus =  (ld_brt) ? baud_rate[15:8]  : 
                  (ld_brb) ? baud_rate[7:0]   :
                  (ld_dbus) ? read_data : 
                  8'hzz;

endmodule