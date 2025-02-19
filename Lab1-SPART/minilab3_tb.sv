module minilab3_tb ();

logic    clk, 
        rst;
// singals tying spart and driver together 
logic   iocs, 
        iorw,
        rda,
        tbr, 
        remote_rda, 
        remote_tbr;
logic [1:0] ioaddr, br_cfg;
wire [7:0] databus, remote_databus; 

// I/O from spart
logic txd, rxd;

//tb internal singals 
logic [9:0] shift_reg;
logic [7:0] test_word;

logic remote_iocs;

logic ld_br, remote_iorw;
assign ld_br = (ioaddr === 2'b00) ? 1'b0 : 1'b1;

// always @(*) begin 
//     remote_iorw <= (ld_br) ? iorw : ~iorw;
// end

assign remote_databus = (ld_br) ? databus : 
                        (remote_iocs) ? test_word : 
                        8'hzz;


spart_test spart0(   .clk(clk),
                .rst(rst),
                .iocs(iocs),
                .iorw(iorw),
                .rda(rda),
                .tbr(tbr),
                .ioaddr(ioaddr),
                .databus(databus),
                .txd(txd),
                .rxd(rxd)
            );

spart spart1(   .clk(clk),
                .rst(rst),
                .iocs(iocs),
                .iorw(remote_iorw),
                .rda(remote_rda),
                .tbr(remote_tbr),
                .ioaddr(ioaddr),
                .databus(remote_databus),
                .txd(rxd),
                .rxd(txd)
            );

// Instantiate your driver here
driver driver0( .clk(clk),
                .rst(rst),
                .br_cfg(br_cfg),
                .iocs(iocs),
                .iorw(iorw),
                .rda(rda),
                .tbr(tbr),
                .ioaddr(ioaddr),
                .databus(databus)
            );

initial begin 
    clk = 0; 
    rst = 1; 
    br_cfg = 2'b00;      //default to the lowest baud rate

    @(negedge clk) rst = 0;

    remote_iorw = iorw;

    ////////////////////////////////////////////////////////////////////////////////
    // TEST: CHANGE BAUD RATE DIP SETTING -> VERIFY THAT WAS READ OVER TO SPART UNIT
    ////////////////////////////////////////////////////////////////////////////////
    $display("TEST: CHANGE BAUD RATE DIP SETTING -> VERIFY THAT WAS READ OVER TO SPART UNIT");
    // first check was the original baud rate sent to the spart unit   
    repeat (5) @(posedge clk);
    if (spart0.div_buf !== 16'h145a) begin 
        $display("ERROR: baud rate was not set to 4800");
        $stop();
    end else
        $display("SUCCESS: baud rate was set to 4800 in spart unit");

    // now change the baud rate to 9600
    @(negedge clk) br_cfg = 2'b01;
    repeat (5) @(posedge clk);
    if (spart0.div_buf !== 16'h0a2c) begin 
        $display("ERROR: baud rate was not set to 9600");
        $stop();
    end else 
        $display("SUCCESS: baud rate was set to 9600 in spart unit");


    repeat(5) @(posedge clk);
    ///////////////////////////////////////////////////
    // TEST: SEND A WORD THROUGH THE COMMUNICATION UNIT
    ///////////////////////////////////////////////////
    @(posedge clk) begin
        remote_iocs = 1'b1;
        remote_iorw = ~iorw;
        test_word = 8'haa;
    end
    @(posedge clk) remote_iocs = 1'b0;

/*
    fork
        begin : init_rx_to
            repeat (25000) @(posedge clk);
            $display("ERROR: timeout on wait for rda to go high");
            $stop();
        end : init_rx_to
        begin
            @(posedge rda) begin
                disable init_rx_to;
                if (spart0.receive_data !== test_word) begin 
                    $display("ERROR: signal recieved by SPART was not the same as the signal sent"); 
                    $stop();
                end 
                $display("SUCCESS: signal recieved by SPART was the same as the signal sent");
            end
        end
    join
    
    $stop();
end


always #5 clk = ~clk;

endmodule