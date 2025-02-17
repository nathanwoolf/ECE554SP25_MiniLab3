module minilab3_tb ();

wire    clk, 
        rst;
// singals tying spart and driver together 
wire    iocs, 
        iorw,
        rda,
        tbr;
wire [1:0] ioaddr, br_cfg;
wire [7:0] databus; 

// I/O from spart
wire txd, rxd;

//tb internal singals 
wire [9:0] test_word;

spart spart0(   .clk(clk),
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
    br_config = 2'b00;      //default to the lowest baud rate

    @(negedge clk) rst = 0;

    ////////////////////////////////////////////////////////////////////////////////
    // TEST: CHANGE BAUD RATE DIP SETTING -> VERIFY THAT WAS READ OVER TO SPART UNIT
    ////////////////////////////////////////////////////////////////////////////////
    $display("TEST: CHANGE BAUD RATE DIP SETTING -> VERIFY THAT WAS READ OVER TO SPART UNIT");
    // first check was the original baud rate sent to the spart unit   
    repeat (5) @(posedge clk);
    if (spart0.div_buf !== 16'h028A) begin 
        $display("ERROR: baud rate was not set to 4800");
        $stop();
    end else
        $dsiplay("SUCCESS: baud rate was set to 4800 in spart unit");

    // now change the baud rate to 9600
    @(negedge clk) br_config = 2'b01;
    if (spart0.div_buf !== 16'h0145) begin 
        $display("ERROR: baud rate was not set to 9600");
        $stop();
    end else 
        $display("SUCCESS: baud rate was set to 9600 in spart unit");


    repeat(5) @(posedge clk);
    ///////////////////////////////////////////////////
    // TEST: SEND A WORD THROUGH THE COMMUNICATION UNIT
    ///////////////////////////////////////////////////
    test_word = {1'b1, 8'hA5, 1'b0};            // ** we have to build in start and stop bits **

    @(negedge clk) rx = test_word[0]; 

    $display("TEST: SEND A WORD THROUGH THE COMMUNICATION UNIT");
    // two clk cycles after each shift signal, we'll change what rx is looking at
    for (int i = 1; i < 9; i++) begin 
        @(negedge spart0.baud_en)
        rx = test_word[i];
    end

    fork
        begin : init_rx_to
            repeat (70000) @(posedge clk);
            $display("ERROR: timeout on wait for rda to go high");
            $stop();
        end : init_rx_to
        begin
            @(posedge rda) begin
                disable init_rx_to;
                if (databus !== test_word) begin 
                    $display("ERROR: signal recieved was not the same as the signal sent"); 
                    $stop();
                end 
                $display("SUCCESS: signal recieved was the same as the signal sent");
            end
        end
    join
    
end


always #5 clk = ~clk;

endmodule