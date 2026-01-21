`timescale 1ns / 1ps

module tb_regfile;

    // Παράμετροι
    parameter DATAWIDTH = 32;

    // Σήματα Εισόδου (Regs)
    reg clk;
    reg resetn;
    reg write;
    
    reg [3:0] readReg1, readReg2, readReg3, readReg4;
    reg [3:0] writeReg1, writeReg2;
    reg [DATAWIDTH-1:0] writeData1, writeData2;

    // Σήματα Εξόδου (Wires)
    wire [DATAWIDTH-1:0] readData1, readData2, readData3, readData4;

    // Μετρητής σφαλμάτων
    integer errors;

    // Instantiation του Regfile
    regfile #(
        .DATAWIDTH(DATAWIDTH)
    ) uut (
        .clk(clk), 
        .resetn(resetn), 
        .write(write), 
        .readReg1(readReg1), .readReg2(readReg2), .readReg3(readReg3), .readReg4(readReg4), 
        .writeReg1(writeReg1), .writeReg2(writeReg2), 
        .writeData1(writeData1), .writeData2(writeData2), 
        .readData1(readData1), .readData2(readData2), .readData3(readData3), .readData4(readData4)
    );

    // Δημιουργία Ρολογιού (Περίοδος 10ns)
    always #5 clk = ~clk;

    // Διαδικασία Ελέγχου
    initial begin
        // Αρχικοποίηση
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_regfile);
        
        clk = 0;
        resetn = 0;
        write = 0;
        errors = 0;
        
        // Αρχικές τιμές διευθύνσεων
        readReg1 = 0; readReg2 = 0; readReg3 = 0; readReg4 = 0;
        writeReg1 = 0; writeReg2 = 0;
        writeData1 = 0; writeData2 = 0;

        $display("============================================================");
        $display("Register File Testbench (Synchronous Read/Write)");
        $display("============================================================");

        // --- TEST 1: Reset ---
        #10 resetn = 1; // Release Reset
        $display("Test 1: Reset Check");
        #2;
        if (readData1 !== 0) begin
            $display("[FAIL] Reset did not clear outputs. Got: %h", readData1);
            errors = errors + 1;
        end else $display("[PASS] Reset cleared outputs.");

        // --- TEST 2: Standard Write & Read (Different Cycles) ---
        // Γράφουμε στο Reg 1 την τιμή 0xAABBCCDD
        @(negedge clk);
        write = 1;
        writeReg1 = 4'd1; 
        writeData1 = 32'hAABBCCDD;
        readReg1 = 4'd0; // Δεν διαβάζουμε το 1 ακόμα
        
        @(negedge clk);
        // Τώρα διαβάζουμε το Reg 1 (χωρίς εγγραφή)
        write = 0;
        readReg1 = 4'd1;
        
        @(negedge clk); // Περιμένουμε ένα κύκλο να βγει η έξοδος (λόγω σύγχρονης ανάγνωσης)
        #1; 
        if (readData1 === 32'hAABBCCDD) $display("[PASS] Standard Write/Read Reg1: %h", readData1);
        else begin
            $display("[FAIL] Standard Write/Read Reg1. Expected AABBCCDD, Got %h", readData1);
            errors = errors + 1;
        end

        // --- TEST 3: FORWARDING TEST (Critical) ---
        // Γράφουμε στο Reg 5 και ΤΑΥΤΟΧΡΟΝΑ διαβάζουμε το Reg 5.
        // Πρέπει να δούμε τη ΝΕΑ τιμή στον επόμενο κύκλο, όχι την παλιά (0).
        $display("Test 3: Forwarding Check (Write & Read Same Address)");
        
        @(negedge clk);
        write = 1;
        writeReg1 = 4'd5;
        writeData1 = 32'hDEADBEEF;
        
        // Ζητάμε ανάγνωση από την ίδια διεύθυνση (5) ταυτόχρονα
        readReg1 = 4'd5; 
        
        @(posedge clk); // Χτύπος ρολογιού -> Γίνεται εγγραφή ΚΑΙ ανάγνωση
        #2; // Μικρή καθυστέρηση μετά το ρολόι
        
        // Επειδή είναι σύγχρονο το read με forwarding logic, 
        // η έξοδος readData1 πρέπει να έχει ενημερωθεί ΑΜΕΣΑ σε αυτόν τον κύκλο (από το always block)
        if (readData1 === 32'hDEADBEEF) 
            $display("[PASS] Forwarding Works! ReadData1 updated immediately to %h", readData1);
        else begin
            $display("[FAIL] Forwarding Failed. Expected DEADBEEF, Got %h", readData1);
            errors = errors + 1;
        end

        // --- TEST 4: Cross Port Forwarding ---
        // Γράφουμε από το WritePort 2 στο Reg 10
        // Διαβάζουμε από το ReadPort 3 το Reg 10
        $display("Test 4: Cross Port Forwarding (Write Port 2 -> Read Port 3)");
        
        @(negedge clk);
        write = 1;
        writeReg2 = 4'd10;
        writeData2 = 32'h12345678;
        
        readReg3 = 4'd10;
        
        @(posedge clk);
        #2;
        if (readData3 === 32'h12345678) 
            $display("[PASS] Cross Port Forwarding Works! Got %h", readData3);
        else begin
            $display("[FAIL] Cross Port Forwarding Failed. Expected 12345678, Got %h", readData3);
            errors = errors + 1;
        end

        // --- Summary ---
        $display("============================================================");
        if (errors == 0) $display("SUCCESS: All tests passed. Register File is ready.");
        else $display("FAILURE: Found %0d errors.", errors);
        $display("============================================================");
        $finish;
    end

endmodule