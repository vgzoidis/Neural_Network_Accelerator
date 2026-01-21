//==============================================================================
// Neural Network Testbench - Άσκηση 4
//==============================================================================

`timescale 1ns / 1ps

module tb_nn;

    //==========================================================================
    // Παράμετροι
    //==========================================================================
    parameter CLK_PERIOD = 10;           // 10ns clock period
    parameter NUM_ITERATIONS = 100;      // 100 Επαναλήψεις
    
    //==========================================================================
    // Σήματα Testbench
    //==========================================================================
    reg         clk;
    reg         resetn;
    reg         enable;
    reg  signed [31:0] input_1;
    reg  signed [31:0] input_2;
    wire signed [31:0] final_output;
    wire        total_ovf;
    wire        total_zero;
    wire [2:0]  ovf_fsm_stage;
    wire [2:0]  zero_fsm_stage;
    reg signed [31:0] expected; // Global variable to reference model output

    // Προσωρινές μεταβλητές για την αποφυγή συντακτικών λαθών στην Icarus Verilog
    // (Χρησιμοποιούνται για την αποθήκευση τυχαίων τιμών πριν το πέρασμα στο task)
    reg [31:0] raw_rand;
    reg signed [31:0] temp_in1;
    reg signed [31:0] temp_in2;

    // Μετρητές Στατιστικών
    integer pass_count;
    integer fail_count;
    integer test_count;
    integer iteration;

    //==========================================================================
    // Ενσωμάτωση Μοντέλου Αναφοράς
    //==========================================================================
    `include "nn_model.v"

    //==========================================================================
    // Device Under Test (DUT)
    //==========================================================================
    nn uut (
        .clk            (clk),
        .resetn         (resetn),
        .enable         (enable),
        .input_1        (input_1),
        .input_2        (input_2),
        .final_output   (final_output),
        .total_ovf      (total_ovf),
        .total_zero     (total_zero),
        .ovf_fsm_stage  (ovf_fsm_stage),
        .zero_fsm_stage (zero_fsm_stage)
    );

    //==========================================================================
    // Παραγωγή Ρολογιού (10ns Περίοδος, 50% Duty Cycle)
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Κύρια Διαδικασία Ελέγχου
    //==========================================================================
    initial begin

        $dumpfile("dump.vcd"); // Προσθήκη για δημιουργία αρχείου με τα waveforms

        // 1. Inputs (Stimulus)
        $dumpvars(0, input_1);
        $dumpvars(0, input_2);
        $dumpvars(0, enable);
        $dumpvars(0, clk);
      
        // 2. Comparison
        $dumpvars(0, final_output);
        $dumpvars(0, expected);
        
        // 3. Context
      	$dumpvars(0, pass_count);
      	$dumpvars(0, fail_count);
        $dumpvars(0, iteration);
        
        //4. Status/Flags
        $dumpvars(0, total_ovf);
        $dumpvars(0, total_zero);
        $dumpvars(0, ovf_fsm_stage);
        $dumpvars(0, zero_fsm_stage); 

        // --- Αρχικοποίηση ---
        pass_count = 0;
        fail_count = 0;
        test_count = 0;
        resetn = 0;
        enable = 0;
        input_1 = 0;
        input_2 = 0;

        // --- Διαδικασία Reset ---
        #(CLK_PERIOD * 2);
        resetn = 1;
        #(CLK_PERIOD * 2);

        // --- Φόρτωση Βαρών από ROM ---
        $display("Loading weights...");
        enable = 1;
        @(posedge clk);
        enable = 0;
        
        // Αναμονή για μετάβαση LOADING -> IDLE
        repeat(15) @(posedge clk);
        $display("Weights loaded. Starting tests...\n");

        //======================================================================
        // Κύριος Βρόχος: 100 Επαναλήψεις
        //======================================================================
        for (iteration = 0; iteration < NUM_ITERATIONS; iteration = iteration + 1) begin
            
            //------------------------------------------------------------------
            // Τεστ 1: Τυχαίο ζεύγος στο εύρος [-4096, 4095]
            //------------------------------------------------------------------
            // 1. Γεννήτρια Raw (0 έως 8191)
            raw_rand = $urandom_range(8191, 0);
            // 2. Μετατόπιση κατά -4096
            temp_in1 = $signed(raw_rand) - 32'd4096;
            
            raw_rand = $urandom_range(8191, 0);
            temp_in2 = $signed(raw_rand) - 32'd4096;
            
            run_test(temp_in1, temp_in2, "Normal Range [-4096, 4095]");

            //------------------------------------------------------------------
            // Τεστ 2: Θετική Υπερχείλιση [max_pos/2, max_pos]
            //------------------------------------------------------------------
            raw_rand = $urandom_range(32'h7FFFFFFF, 32'h3FFFFFFF);
            temp_in1 = $signed({1'b0, raw_rand[30:0]}); // Εξαναγκασμός θετικού προσήμου
            
            raw_rand = $urandom_range(32'h7FFFFFFF, 32'h3FFFFFFF);
            temp_in2 = $signed({1'b0, raw_rand[30:0]});
            
            run_test(temp_in1, temp_in2, "Positive Overflow Check");

            //------------------------------------------------------------------
            // Τεστ 3: Αρνητική Υπερχείλιση [max_neg, max_neg/2]
            //------------------------------------------------------------------
            raw_rand = $urandom_range(32'h3FFFFFFF, 0); 
            temp_in1 = $signed({1'b1, raw_rand[30:0]}); // Εξαναγκασμός αρνητικού προσήμου
            
            raw_rand = $urandom_range(32'h3FFFFFFF, 0);
            temp_in2 = $signed({1'b1, raw_rand[30:0]});
            
            run_test(temp_in1, temp_in2, "Negative Overflow Check");
        end

        //======================================================================
        // Τελική Αναφορά
        //======================================================================
        $display("\n============================================================");
        $display("FINAL REPORT");
        $display("============================================================");
        $display("Total Test Cases: %0d", test_count);
        $display("PASSED:           %0d", pass_count);
        $display("FAILED:           %0d", fail_count);
        $display("Success Rate:     %0d / %0d", pass_count, test_count);
        
        if (fail_count == 0)
            $display("RESULT: SUCCESS (All tests passed)");
        else
            $display("RESULT: FAILURE (See errors above)");
        $display("============================================================");

        #(CLK_PERIOD * 5);
        $finish;
    end

    //==========================================================================
    // Task: run_test
    // Εκτελεί διέγερση, αναμονή, σύγκριση και αναφορά
    //==========================================================================
    task run_test;
        input signed [31:0] in1;
        input signed [31:0] in2;
        input [255:0] test_desc;
        
        begin
            test_count = test_count + 1;

            // 1. Εφαρμογή Εισόδων
            input_1 = in1;
            input_2 = in2;

            // 2. Παλμός Enable
            @(posedge clk);
            enable = 1;
            @(posedge clk);
            enable = 0;

            // 3. Υπολογισμός Αναμενόμενης Τιμής
            expected = nn_model(in1, in2);

            // 4. Αναμονή για την καθυστέρηση του κυκλώματος του νευρωνικού δικτύου
			repeat(6) @(posedge clk); // Το αποτέλεσμα εμφανίζεται μετά από 6 κύκλους ρολογιού
          
            // 5. Σύγκριση & Αναφορά
            if (final_output === expected) begin
                pass_count = pass_count + 1; // Τα PASS δεν τυπώνονται για να μην γεμίζει η οθόνη
            end else begin
                fail_count = fail_count + 1;
                $display("------------------------------------------------------------");
                $display("ERROR at time %0t ns", $time);
                $display("Test Type:      %s", test_desc);
                $display("Input 1:        %d (0x%h)", in1, in1);
                $display("Input 2:        %d (0x%h)", in2, in2);
                $display("DUT Output:     %d (0x%h)", final_output, final_output);
                $display("Ref Output:     %d (0x%h)", expected, expected);
                $display("------------------------------------------------------------");
            end

            #(CLK_PERIOD); // Μικρή παύση πριν το επόμενο τεστ
        end
    endtask

endmodule