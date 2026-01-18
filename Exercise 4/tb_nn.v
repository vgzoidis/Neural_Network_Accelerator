//==============================================================================
// Neural Network Testbench - Άσκηση 4
// Έλεγχος ορθής λειτουργίας του νευρωνικού δικτύου
//==============================================================================

`timescale 1ns / 1ps

module tb_nn;

    //==========================================================================
    // Σταθερές για το μοντέλο αναφοράς (ίδιες με το nn.v)
    //==========================================================================
    localparam [31:0] ROM_SHIFT_BIAS_1 = 32'h00000002;
    localparam [31:0] ROM_SHIFT_BIAS_2 = 32'h00000002;
    localparam [31:0] ROM_WEIGHT_1     = 32'h00000003;
    localparam [31:0] ROM_BIAS_1       = 32'h00000001;
    localparam [31:0] ROM_WEIGHT_2     = 32'h00000002;
    localparam [31:0] ROM_BIAS_2       = 32'h00000002;
    localparam [31:0] ROM_WEIGHT_3     = 32'h00000002;
    localparam [31:0] ROM_WEIGHT_4     = 32'h00000001;
    localparam [31:0] ROM_BIAS_3       = 32'h00000003;
    localparam [31:0] ROM_SHIFT_BIAS_3 = 32'h00000001;
    localparam [31:0] MAX_POSITIVE     = 32'h7FFFFFFF;

    //==========================================================================
    // Σήματα Testbench
    //==========================================================================
    reg         clk;
    reg         resetn;
    reg         enable;
    reg  [31:0] input_1;
    reg  [31:0] input_2;
    wire [31:0] final_output;
    wire        total_ovf;
    wire        total_zero;
    wire [2:0]  ovf_fsm_stage;
    wire [2:0]  zero_fsm_stage;

    // Μετρητές για στατιστικά
    integer pass_count;
    integer fail_count;
    integer test_count;
    integer i;

    // Αποτέλεσμα αναφοράς
    reg [31:0] reference_output;
    reg        reference_ovf;

    // Αριθμός κύκλων FSM (7 καταστάσεις)
    localparam FSM_CYCLES = 8;

    //==========================================================================
    // Instance του Neural Network
    //==========================================================================
    nn uut (
        .clk           (clk),
        .resetn        (resetn),
        .enable        (enable),
        .input_1       (input_1),
        .input_2       (input_2),
        .final_output  (final_output),
        .total_ovf     (total_ovf),
        .total_zero    (total_zero),
        .ovf_fsm_stage (ovf_fsm_stage),
        .zero_fsm_stage(zero_fsm_stage)
    );

    //==========================================================================
    // Δημιουργία σήματος ρολογιού - περίοδος 10ns, duty cycle 50%
    //==========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //==========================================================================
    // Συνάρτηση μοντέλου αναφοράς (nn_model)
    // Υπολογίζει το αναμενόμενο αποτέλεσμα του νευρωνικού
    //==========================================================================
    function [32:0] nn_model;  // 33 bits: [32] = overflow flag, [31:0] = result
        input signed [31:0] in1;
        input signed [31:0] in2;
        
        reg signed [31:0] inter_1, inter_2;
        reg signed [63:0] temp_mult;
        reg signed [31:0] inter_3, inter_4;
        reg signed [31:0] term1, term2;
        reg signed [31:0] sum1, result;
        reg overflow;
        begin
            overflow = 0;
            
            // Stage 1: Pre-processing (arithmetic shift right)
            inter_1 = in1 >>> ROM_SHIFT_BIAS_1[4:0];
            inter_2 = in2 >>> ROM_SHIFT_BIAS_2[4:0];
            
            // Stage 2: Input Layer - Neuron 1
            // inter_3 = inter_1 * weight_1 + bias_1
            temp_mult = inter_1 * $signed(ROM_WEIGHT_1);
            if (temp_mult > $signed(MAX_POSITIVE) || temp_mult < $signed(-32'h80000000)) begin
                overflow = 1;
            end
            inter_3 = temp_mult[31:0] + $signed(ROM_BIAS_1);
            // Check add overflow
            if ((temp_mult[31] == ROM_BIAS_1[31]) && (inter_3[31] != temp_mult[31])) begin
                overflow = 1;
            end
            
            // Stage 2: Input Layer - Neuron 2
            // inter_4 = inter_2 * weight_2 + bias_2
            temp_mult = inter_2 * $signed(ROM_WEIGHT_2);
            if (temp_mult > $signed(MAX_POSITIVE) || temp_mult < $signed(-32'h80000000)) begin
                overflow = 1;
            end
            inter_4 = temp_mult[31:0] + $signed(ROM_BIAS_2);
            if ((temp_mult[31] == ROM_BIAS_2[31]) && (inter_4[31] != temp_mult[31])) begin
                overflow = 1;
            end
            
            // Stage 3: Output Layer
            // term1 = inter_3 * weight_3
            temp_mult = inter_3 * $signed(ROM_WEIGHT_3);
            if (temp_mult > $signed(MAX_POSITIVE) || temp_mult < $signed(-32'h80000000)) begin
                overflow = 1;
            end
            term1 = temp_mult[31:0];
            
            // term2 = inter_4 * weight_4
            temp_mult = inter_4 * $signed(ROM_WEIGHT_4);
            if (temp_mult > $signed(MAX_POSITIVE) || temp_mult < $signed(-32'h80000000)) begin
                overflow = 1;
            end
            term2 = temp_mult[31:0];
            
            // sum1 = term1 + term2
            sum1 = term1 + term2;
            if ((term1[31] == term2[31]) && (sum1[31] != term1[31])) begin
                overflow = 1;
            end
            
            // result = sum1 + bias_3
            result = sum1 + $signed(ROM_BIAS_3);
            if ((sum1[31] == ROM_BIAS_3[31]) && (result[31] != sum1[31])) begin
                overflow = 1;
            end
            
            // Stage 4: Post-processing (arithmetic shift left)
            result = result <<< ROM_SHIFT_BIAS_3[4:0];
            
            // Return result with overflow flag
            if (overflow) begin
                nn_model = {1'b1, MAX_POSITIVE};
            end
            else begin
                nn_model = {1'b0, result};
            end
        end
    endfunction

    //==========================================================================
    // Task για εκτέλεση ενός τεστ
    //==========================================================================
    task run_test;
        input signed [31:0] test_in1;
        input signed [31:0] test_in2;
        input [8*32-1:0] test_name;
        
        reg [32:0] ref_result;
        begin
            // Εφαρμογή εισόδων
            input_1 = test_in1;
            input_2 = test_in2;
            
            // Υπολογισμός αναμενόμενου αποτελέσματος
            ref_result = nn_model(test_in1, test_in2);
            reference_output = ref_result[31:0];
            reference_ovf = ref_result[32];
            
            // Ενεργοποίηση νευρωνικού
            enable = 1;
            @(posedge clk);
            enable = 0;
            
            // Αναμονή για ολοκλήρωση FSM
            repeat(FSM_CYCLES) @(posedge clk);
            
            // Επιπλέον αναμονή για σταθεροποίηση
            #2;
            
            test_count = test_count + 1;
            
            // Σύγκριση αποτελεσμάτων
            if (reference_ovf) begin
                // Αναμένουμε overflow
                if (total_ovf && final_output == MAX_POSITIVE) begin
                    pass_count = pass_count + 1;
                    // $display("PASS [%0d]: %s - Overflow detected correctly", test_count, test_name);
                end
                else begin
                    fail_count = fail_count + 1;
                    $display("FAIL [%0d] at time %0t: %s", test_count, $time, test_name);
                    $display("  Inputs: input_1=0x%08h (%0d), input_2=0x%08h (%0d)", 
                             test_in1, $signed(test_in1), test_in2, $signed(test_in2));
                    $display("  Expected: OVERFLOW (0x%08h)", MAX_POSITIVE);
                    $display("  Got: ovf=%b, output=0x%08h", total_ovf, final_output);
                end
            end
            else begin
                // Αναμένουμε κανονικό αποτέλεσμα
                if (!total_ovf && final_output == reference_output) begin
                    pass_count = pass_count + 1;
                    // $display("PASS [%0d]: %s - Result=0x%08h", test_count, test_name, final_output);
                end
                else begin
                    fail_count = fail_count + 1;
                    $display("FAIL [%0d] at time %0t: %s", test_count, $time, test_name);
                    $display("  Inputs: input_1=0x%08h (%0d), input_2=0x%08h (%0d)", 
                             test_in1, $signed(test_in1), test_in2, $signed(test_in2));
                    $display("  Expected: 0x%08h (%0d)", reference_output, $signed(reference_output));
                    $display("  Got: 0x%08h (%0d), ovf=%b", final_output, $signed(final_output), total_ovf);
                end
            end
        end
    endtask

    //==========================================================================
    // Συνάρτηση για τυχαίο αριθμό σε εύρος
    //==========================================================================
    function signed [31:0] random_in_range;
        input signed [31:0] min_val;
        input signed [31:0] max_val;
        reg [31:0] range;
        reg [31:0] rand_val;
        begin
            range = max_val - min_val + 1;
            rand_val = $urandom_range(0, range - 1);
            random_in_range = min_val + rand_val;
        end
    endfunction

    //==========================================================================
    // Κύριο τεστ
    //==========================================================================
    initial begin
        // Αρχικοποίηση
        $display("============================================================");
        $display("Neural Network Testbench - Start");
        $display("Clock period: 10ns, Duty cycle: 50%%");
        $display("============================================================");
        
        pass_count = 0;
        fail_count = 0;
        test_count = 0;
        
        // Αρχικοποίηση σημάτων
        resetn = 0;
        enable = 0;
        input_1 = 0;
        input_2 = 0;
        
        // Reset
        #20;
        resetn = 1;
        #20;
        
        // Πρώτη ενεργοποίηση για φόρτωση βαρών
        enable = 1;
        @(posedge clk);
        enable = 0;
        repeat(3) @(posedge clk);
        
        //----------------------------------------------------------------------
        // 100 επαναλήψεις τεστ
        //----------------------------------------------------------------------
        for (i = 0; i < 100; i = i + 1) begin
            $display("\n--- Iteration %0d/100 ---", i + 1);
            
            //------------------------------------------------------------------
            // Test 1: Τυχαίο ζεύγος με εύρος [-4096, 4095]
            //------------------------------------------------------------------
            run_test(
                random_in_range(-4096, 4095),
                random_in_range(-4096, 4095),
                "Normal range [-4096, 4095]"
            );
            
            //------------------------------------------------------------------
            // Test 2: Θετικοί αριθμοί για overflow
            // Εύρος: [max_positive/2, max_positive]
            //------------------------------------------------------------------
            run_test(
                random_in_range(32'h3FFFFFFF, 32'h7FFFFFFF),
                random_in_range(32'h3FFFFFFF, 32'h7FFFFFFF),
                "Positive overflow range"
            );
            
            //------------------------------------------------------------------
            // Test 3: Αρνητικοί αριθμοί για overflow
            // Εύρος: [max_negative, max_negative/2]
            //------------------------------------------------------------------
            run_test(
                random_in_range(-32'h80000000, -32'h40000000),
                random_in_range(-32'h80000000, -32'h40000000),
                "Negative overflow range"
            );
        end
        
        //----------------------------------------------------------------------
        // Αποτελέσματα
        //----------------------------------------------------------------------
        $display("\n============================================================");
        $display("Neural Network Testbench - Complete");
        $display("Results: %0d PASS / %0d Total Tests", pass_count, test_count);
        $display("Failed: %0d", fail_count);
        $display("============================================================");
        
        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end
        else begin
            $display("*** SOME TESTS FAILED ***");
        end
        
        #100;
        $finish;
    end

    //==========================================================================
    // Waveform dump για προσομοίωση
    //==========================================================================
    initial begin
        $dumpfile("tb_nn.vcd");
        $dumpvars(0, tb_nn);
    end

endmodule
