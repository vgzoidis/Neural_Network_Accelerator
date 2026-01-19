//==============================================================================
// Neural Network Testbench - Άσκηση 4
// 
// Σύμφωνα με την εκφώνηση:
//   - Ρολόι με περίοδο 10ns και duty cycle 50%
//   - Σύγκριση εξόδου κυκλώματος με nn_model
//   - Εκτύπωση χρονικής στιγμής, εισόδων, εξόδων σε περίπτωση λάθους
//   - Μέτρηση σωστών συγκρίσεων (PASS / total)
//   - 100 επαναλήψεις × 3 τεστ ανά επανάληψη:
//     1. Τυχαίο ζεύγος [-4096, 4095]
//     2. Τυχαίο ζεύγος [max_pos/2, max_pos] για θετική υπερχείλιση
//     3. Τυχαίο ζεύγος [max_neg, max_neg/2] για αρνητική υπερχείλιση
//==============================================================================

`timescale 1ns / 1ps

module tb_nn;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter CLK_PERIOD = 10;           // 10ns clock period (100 MHz)
    parameter NUM_ITERATIONS = 100;      // 100 επαναλήψεις
    parameter TESTS_PER_ITER = 3;        // 3 τεστ ανά επανάληψη
    
    // Εύρος τιμών για τεστ
    parameter signed [31:0] RANGE_MIN     = -32'd4096;
    parameter signed [31:0] RANGE_MAX     = 32'd4095;
    parameter signed [31:0] MAX_POSITIVE  = 32'h7FFFFFFF;
    parameter signed [31:0] MAX_NEGATIVE  = 32'h80000000;

    //==========================================================================
    // Testbench Signals
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

    //==========================================================================
    // Test Counters
    //==========================================================================
    integer pass_count;
    integer fail_count;
    integer test_count;
    integer iteration;

    //==========================================================================
    // Reference Model Function (included from external file)
    //==========================================================================
    `include "nn_model.v"

    //==========================================================================
    // Device Under Test (Instance του νευρωνικού κυκλώματος)
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
    // Clock Generation - Περίοδος 10ns, duty cycle 50%
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        // Αρχικοποίηση σημάτων
        $display("============================================================");
        $display("Neural Network Testbench");
        $display("100 επαναλήψεις x 3 τεστ = 300 συνολικά τεστ");
        $display("============================================================");
        
        pass_count = 0;
        fail_count = 0;
        test_count = 0;
        resetn = 0;
        enable = 0;
        input_1 = 32'd0;
        input_2 = 32'd0;

        // Εφαρμογή reset
        #(CLK_PERIOD * 2);
        resetn = 1;
        #(CLK_PERIOD * 2);

        // Ενεργοποίηση και φόρτωση βαρών από ROM
        $display("\n--- Φόρτωση βαρών από ROM ---");
        enable = 1;
        @(posedge clk);
        enable = 0;
        
        // Αναμονή για ολοκλήρωση φόρτωσης (LOADING -> IDLE)
        // S_DEACTIVATED -> S_LOADING (5+ cycles) -> S_IDLE
        repeat(15) @(posedge clk);
        
        $display("Βάρη φορτώθηκαν επιτυχώς\n");

        //======================================================================
        // Κύριος βρόχος: 100 επαναλήψεις
        //======================================================================
        for (iteration = 0; iteration < NUM_ITERATIONS; iteration = iteration + 1) begin
            
            //------------------------------------------------------------------
            // Τεστ 1: Τυχαίο ζεύγος στο εύρος [-4096, 4095]
            //------------------------------------------------------------------
            run_test(
                $signed($urandom_range(0, 8191)) - 32'd4096,  // [-4096, 4095]
                $signed($urandom_range(0, 8191)) - 32'd4096,
                "Normal Range"
            );

            //------------------------------------------------------------------
            // Τεστ 2: Τυχαίο ζεύγος στο εύρος [max_pos/2, max_pos]
            // για έλεγχο υπερχείλισης με θετικούς αριθμούς
            //------------------------------------------------------------------
            run_test(
                $signed({1'b0, $urandom_range(32'h3FFFFFFF, 32'h7FFFFFFF)[30:0]}),
                $signed({1'b0, $urandom_range(32'h3FFFFFFF, 32'h7FFFFFFF)[30:0]}),
                "Positive Overflow"
            );

            //------------------------------------------------------------------
            // Τεστ 3: Τυχαίο ζεύγος στο εύρος [max_neg, max_neg/2]
            // για έλεγχο υπερχείλισης με αρνητικούς αριθμούς
            //------------------------------------------------------------------
            run_test(
                $signed({1'b1, $urandom_range(0, 32'h3FFFFFFF)[30:0]}),
                $signed({1'b1, $urandom_range(0, 32'h3FFFFFFF)[30:0]}),
                "Negative Overflow"
            );

            // Εμφάνιση προόδου κάθε 10 επαναλήψεις
            if ((iteration + 1) % 10 == 0) begin
                $display("Πρόοδος: %0d/%0d επαναλήψεις ολοκληρώθηκαν", 
                         iteration + 1, NUM_ITERATIONS);
            end
        end

        //======================================================================
        // Τελικό Σύνολο
        //======================================================================
        $display("\n============================================================");
        $display("Neural Network Testbench - Ολοκληρώθηκε");
        $display("============================================================");
        $display("Αποτελέσματα: %0d PASS / %0d συνολικά τεστ", pass_count, test_count);
        $display("Αποτυχίες:    %0d FAIL", fail_count);
        if (fail_count == 0)
            $display(">>> ΟΛΕΣ ΟΙ ΔΟΚΙΜΕΣ ΕΠΙΤΥΧΕΙΣ <<<");
        else
            $display(">>> ΥΠΑΡΧΟΥΝ ΑΠΟΤΥΧΙΕΣ <<<");
        $display("============================================================");

        #(CLK_PERIOD * 10);
        $finish;
    end

    //==========================================================================
    // Test Task
    // 
    // Εκτελεί ένα τεστ:
    //   1. Θέτει τις εισόδους
    //   2. Ενεργοποιεί το νευρωνικό
    //   3. Περιμένει για την ολοκλήρωση (καθυστέρηση κυκλώματος)
    //   4. Συγκρίνει με το reference model
    //   5. Εκτυπώνει αποτέλεσμα (PASS ή λεπτομερές FAIL)
    //==========================================================================
    task run_test;
        input signed [31:0] in1;
        input signed [31:0] in2;
        input [20*8-1:0] test_type;  // String για τον τύπο τεστ
        
        reg [31:0] expected;
        begin
            test_count = test_count + 1;
            
            // Θέση εισόδων
            input_1 = in1;
            input_2 = in2;
            
            // Ενεργοποίηση του νευρωνικού δικτύου
            @(posedge clk);
            enable = 1;
            @(posedge clk);
            enable = 0;
            
            // Αναμονή για ολοκλήρωση υπολογισμού
            // FSM: IDLE -> PREPROCESS -> INPUT_LAYER -> OUTPUT_LAYER -> POSTPROCESS -> IDLE
            // Με σύγχρονη ανάγνωση regfile, χρειάζονται περισσότεροι κύκλοι
            repeat(12) @(posedge clk);
            
            // Λήψη αναμενόμενου αποτελέσματος από το reference model
            expected = nn_model(in1, in2);
            
            // Σύγκριση αποτελεσμάτων
            if (final_output === expected) begin
                pass_count = pass_count + 1;
                // Δεν εκτυπώνουμε τα PASS για να μην γεμίζει η οθόνη
            end
            else begin
                // FAIL: Εκτύπωση λεπτομερειών σύμφωνα με την εκφώνηση
                $display("------------------------------------------------------------");
                $display("FAIL στη χρονική στιγμή: %0t ns", $time);
                $display("  Τύπος τεστ:    %s", test_type);
                $display("  Είσοδος 1:     0x%08h (%0d)", in1, $signed(in1));
                $display("  Είσοδος 2:     0x%08h (%0d)", in2, $signed(in2));
                $display("  Έξοδος κυκλώματος:  0x%08h (%0d)", final_output, $signed(final_output));
                $display("  Έξοδος αναφοράς:    0x%08h (%0d)", expected, $signed(expected));
                $display("  Overflow:      %b (stage: %b)", total_ovf, ovf_fsm_stage);
                $display("------------------------------------------------------------");
                fail_count = fail_count + 1;
            end
            
            // Μικρή καθυστέρηση μεταξύ τεστ
            #(CLK_PERIOD);
        end
    endtask

endmodule
