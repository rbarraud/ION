/*
    zybo_top.v -- Top level entity for ION demo on Zybo board.

    As of right now this does not actually work. All I want for the time being
    is to make sure I can synthesize the demo entity without the whole thing
    being optimized away.

    So all I do here is connect the MCU module to the very few I/O available on 
    the board. 

    In other wordS: SYNTHESIS DUMMY -- DOES NOT WORK!
*/

module zybo_top 
    (
        // Main clock. See @note1.
        input               CLK_125MHZ_I,
        // Various I/O ports connected to board devices.
        input        [3:0]  BUTTONS_I,
        input        [3:0]  SWITCHES_I,
        output reg   [3:0]  LEDS_O,
        // PMOD E (Std) connector -- PMOD UART (Digilent).
        output reg          PMOD_E_2_TXD_O,
        input               PMOD_E_3_RXD_I
    ); 

    //==== MCU instantiation ===================================================

    reg [31:0] bogoinput;
    wire [31:0] dbg_out;
    reg [31:0] dbg_in;
    reg reset;



    mcu # (
        // Size of Code TCM in 32-bit words.
        .OPTION_CTCM_NUM_WORDS(1024)
    )
    mcu (
        .CLK            (CLK_125MHZ_I),
        .RESET_I        (reset),

        .DEBUG_I        (dbg_in),
        .DEBUG_O        (dbg_out) 
    ); 


    // Bogus logic to keep all MCU outputs relevant.
    always @(*) begin
        LEDS_O = 
        dbg_out[31:28] ^ dbg_out[27:24] ^ dbg_out[23:20] ^ dbg_out[19:16] ^
        dbg_out[15:12] ^ dbg_out[11: 8] ^ dbg_out[ 7: 4] ^ dbg_out[ 3: 0];

        reset = |BUTTONS_I;

        PMOD_E_2_TXD_O = PMOD_E_3_RXD_I;
    end

    // Bogus logic to keep all MCU inputs relevant.
    always @(posedge CLK_125MHZ_I) begin
        if (reset) begin // TODO Async input used as sync reset... 
            bogoinput <= 32'h0;
            dbg_in <= 32'h0;
        end
        else begin 
            bogoinput <= {8{SWITCHES_I}};
            dbg_in <= dbg_out + bogoinput;
        end 
    end    

endmodule

// @note1: Clock active if PHYRSTB is high. PHYRSTB pin unused, pulled high.  
