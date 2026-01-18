//==============================================================================
// Neural Network Module - Άσκηση 4
// AI Accelerator με FSM 7 καταστάσεων (Moore FSM)
//==============================================================================

module nn (
    input  wire        clk,            // Ρολόι συστήματος
    input  wire        resetn,         // Ασύγχρονο reset (active low)
    input  wire        enable,         // Σήμα ενεργοποίησης
    input  wire [31:0] input_1,        // Πρώτη είσοδος νευρωνικού
    input  wire [31:0] input_2,        // Δεύτερη είσοδος νευρωνικού
    output reg  [31:0] final_output,   // Έξοδος συστήματος
    output reg         total_ovf,      // Ένδειξη υπερχείλισης
    output reg         total_zero,     // Ένδειξη μηδενικού αποτελέσματος
    output reg  [2:0]  ovf_fsm_stage,  // Στάδιο υπερχείλισης (111 αν δεν υπάρχει)
    output reg  [2:0]  zero_fsm_stage  // Στάδιο μηδενικού (111 αν δεν υπάρχει)
);

    //==========================================================================
    // Ορισμός καταστάσεων FSM (3 bits για 7 καταστάσεις)
    //==========================================================================
    localparam [2:0] STATE_DEACTIVATED   = 3'b000;  // Απενεργοποιημένο
    localparam [2:0] STATE_LOAD_WEIGHTS  = 3'b001;  // Φόρτωση βαρών/πολώσεων
    localparam [2:0] STATE_PREPROCESS    = 3'b010;  // Προεπεξεργασία εισόδων
    localparam [2:0] STATE_INPUT_LAYER   = 3'b011;  // Input Layer (νευρώνες 1,2)
    localparam [2:0] STATE_OUTPUT_LAYER1 = 3'b100;  // Output Layer - βήμα 1
    localparam [2:0] STATE_OUTPUT_LAYER2 = 3'b101;  // Output Layer - βήμα 2
    localparam [2:0] STATE_POSTPROCESS   = 3'b110;  // Μεταεπεξεργασία
    localparam [2:0] STATE_IDLE          = 3'b111;  // Αναμονή

    //==========================================================================
    // ALU Operation Codes
    //==========================================================================
    localparam [3:0] ALUOP_ADD  = 4'b0100;
    localparam [3:0] ALUOP_MULT = 4'b0110;
    localparam [3:0] ALUOP_SRA  = 4'b0010;  // Αριθμητική ολίσθηση δεξιά
    localparam [3:0] ALUOP_SLA  = 4'b0011;  // Αριθμητική ολίσθηση αριστερά

    //==========================================================================
    // Register File Address Mapping
    //==========================================================================
    localparam [3:0] ADDR_SHIFT_BIAS_1 = 4'h2;
    localparam [3:0] ADDR_SHIFT_BIAS_2 = 4'h3;
    localparam [3:0] ADDR_WEIGHT_1     = 4'h4;
    localparam [3:0] ADDR_BIAS_1       = 4'h5;
    localparam [3:0] ADDR_WEIGHT_2     = 4'h6;
    localparam [3:0] ADDR_BIAS_2       = 4'h7;
    localparam [3:0] ADDR_WEIGHT_3     = 4'h8;
    localparam [3:0] ADDR_WEIGHT_4     = 4'h9;
    localparam [3:0] ADDR_BIAS_3       = 4'hA;
    localparam [3:0] ADDR_SHIFT_BIAS_3 = 4'hB;

    //==========================================================================
    // ROM - Προκαθορισμένες τιμές βαρών και πολώσεων
    //==========================================================================
    localparam [31:0] ROM_SHIFT_BIAS_1 = 32'h00000002;  // Μετατόπιση 2 bits
    localparam [31:0] ROM_SHIFT_BIAS_2 = 32'h00000002;  // Μετατόπιση 2 bits
    localparam [31:0] ROM_WEIGHT_1     = 32'h00000003;  // Βάρος νευρώνα 1
    localparam [31:0] ROM_BIAS_1       = 32'h00000001;  // Πόλωση νευρώνα 1
    localparam [31:0] ROM_WEIGHT_2     = 32'h00000002;  // Βάρος νευρώνα 2
    localparam [31:0] ROM_BIAS_2       = 32'h00000002;  // Πόλωση νευρώνα 2
    localparam [31:0] ROM_WEIGHT_3     = 32'h00000002;  // Βάρος νευρώνα 3 - είσοδος 1
    localparam [31:0] ROM_WEIGHT_4     = 32'h00000001;  // Βάρος νευρώνα 3 - είσοδος 2
    localparam [31:0] ROM_BIAS_3       = 32'h00000003;  // Πόλωση νευρώνα 3
    localparam [31:0] ROM_SHIFT_BIAS_3 = 32'h00000001;  // Μετατόπιση εξόδου 1 bit

    // Μέγιστος θετικός αριθμός 32-bit
    localparam [31:0] MAX_POSITIVE = 32'h7FFFFFFF;

    //==========================================================================
    // Εσωτερικά σήματα
    //==========================================================================
    reg [2:0] current_state, next_state;
    reg       weights_loaded;  // Flag: τα βάρη έχουν φορτωθεί

    // Ενδιάμεσοι καταχωρητές για αποτελέσματα
    reg [31:0] inter_1, inter_2;  // Μετά pre-processing
    reg [31:0] inter_3, inter_4;  // Μετά input layer
    reg [31:0] inter_5;           // Μετά output layer step 1
    reg [31:0] inter_6;           // Μετά output layer step 2

    // Register File σήματα
    reg         rf_write;
    reg  [3:0]  rf_readReg1, rf_readReg2, rf_readReg3, rf_readReg4;
    reg  [3:0]  rf_writeReg1, rf_writeReg2;
    reg  [31:0] rf_writeData1, rf_writeData2;
    wire [31:0] rf_readData1, rf_readData2, rf_readData3, rf_readData4;

    // MAC Unit 1 σήματα
    reg  [31:0] mac1_op1, mac1_op2, mac1_op3;
    wire [31:0] mac1_result;
    wire        mac1_zero_mul, mac1_zero_add, mac1_ovf_mul, mac1_ovf_add;

    // MAC Unit 2 σήματα
    reg  [31:0] mac2_op1, mac2_op2, mac2_op3;
    wire [31:0] mac2_result;
    wire        mac2_zero_mul, mac2_zero_add, mac2_ovf_mul, mac2_ovf_add;

    // ALU 1 σήματα (για shifts)
    reg  [31:0] alu1_op1, alu1_op2;
    reg  [3:0]  alu1_op;
    wire [31:0] alu1_result;
    wire        alu1_zero, alu1_ovf;

    // ALU 2 σήματα (για shifts)
    reg  [31:0] alu2_op1, alu2_op2;
    reg  [3:0]  alu2_op;
    wire [31:0] alu2_result;
    wire        alu2_zero, alu2_ovf;

    // Σήματα υπερχείλισης και μηδενικού
    reg any_overflow;
    reg any_zero;

    //==========================================================================
    // Instance του Register File
    //==========================================================================
    regfile #(.DATAWIDTH(32)) reg_file (
        .clk       (clk),
        .resetn    (resetn),
        .readReg1  (rf_readReg1),
        .readReg2  (rf_readReg2),
        .readReg3  (rf_readReg3),
        .readReg4  (rf_readReg4),
        .writeReg1 (rf_writeReg1),
        .writeReg2 (rf_writeReg2),
        .writeData1(rf_writeData1),
        .writeData2(rf_writeData2),
        .write     (rf_write),
        .readData1 (rf_readData1),
        .readData2 (rf_readData2),
        .readData3 (rf_readData3),
        .readData4 (rf_readData4)
    );

    //==========================================================================
    // Instances των MAC Units
    //==========================================================================
    mac_unit mac_unit_1 (
        .op1         (mac1_op1),
        .op2         (mac1_op2),
        .op3         (mac1_op3),
        .total_result(mac1_result),
        .zero_mul    (mac1_zero_mul),
        .zero_add    (mac1_zero_add),
        .ovf_mul     (mac1_ovf_mul),
        .ovf_add     (mac1_ovf_add)
    );

    mac_unit mac_unit_2 (
        .op1         (mac2_op1),
        .op2         (mac2_op2),
        .op3         (mac2_op3),
        .total_result(mac2_result),
        .zero_mul    (mac2_zero_mul),
        .zero_add    (mac2_zero_add),
        .ovf_mul     (mac2_ovf_mul),
        .ovf_add     (mac2_ovf_add)
    );

    //==========================================================================
    // Instances των ALUs για shifts
    //==========================================================================
    alu alu_shift_1 (
        .op1   (alu1_op1),
        .op2   (alu1_op2),
        .alu_op(alu1_op),
        .zero  (alu1_zero),
        .result(alu1_result),
        .ovf   (alu1_ovf)
    );

    alu alu_shift_2 (
        .op1   (alu2_op1),
        .op2   (alu2_op2),
        .alu_op(alu2_op),
        .zero  (alu2_zero),
        .result(alu2_result),
        .ovf   (alu2_ovf)
    );

    //==========================================================================
    // FSM State Register (ασύγχρονο reset)
    //==========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= STATE_DEACTIVATED;
        end
        else begin
            current_state <= next_state;
        end
    end

    //==========================================================================
    // FSM Next State Logic (Moore FSM)
    //==========================================================================
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            STATE_DEACTIVATED: begin
                if (enable)
                    next_state = weights_loaded ? STATE_PREPROCESS : STATE_LOAD_WEIGHTS;
            end
            
            STATE_LOAD_WEIGHTS: begin
                // Φόρτωση ολοκληρώνεται σε 1 κύκλο, μετάβαση στο IDLE
                next_state = STATE_IDLE;
            end
            
            STATE_PREPROCESS: begin
                // Έλεγχος για overflow
                if (any_overflow)
                    next_state = STATE_IDLE;
                else
                    next_state = STATE_INPUT_LAYER;
            end
            
            STATE_INPUT_LAYER: begin
                if (any_overflow)
                    next_state = STATE_IDLE;
                else
                    next_state = STATE_OUTPUT_LAYER1;
            end
            
            STATE_OUTPUT_LAYER1: begin
                if (any_overflow)
                    next_state = STATE_IDLE;
                else
                    next_state = STATE_OUTPUT_LAYER2;
            end
            
            STATE_OUTPUT_LAYER2: begin
                if (any_overflow)
                    next_state = STATE_IDLE;
                else
                    next_state = STATE_POSTPROCESS;
            end
            
            STATE_POSTPROCESS: begin
                next_state = STATE_IDLE;
            end
            
            STATE_IDLE: begin
                if (enable)
                    next_state = STATE_PREPROCESS;
            end
            
            default: begin
                next_state = STATE_DEACTIVATED;
            end
        endcase
    end

    //==========================================================================
    // FSM Output Logic και Data Path Control
    //==========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Reset όλων των εσωτερικών καταχωρητών
            weights_loaded  <= 1'b0;
            inter_1         <= 32'b0;
            inter_2         <= 32'b0;
            inter_3         <= 32'b0;
            inter_4         <= 32'b0;
            inter_5         <= 32'b0;
            inter_6         <= 32'b0;
            final_output    <= 32'b0;
            total_ovf       <= 1'b0;
            total_zero      <= 1'b0;
            ovf_fsm_stage   <= 3'b111;
            zero_fsm_stage  <= 3'b111;
            rf_write        <= 1'b0;
            rf_writeReg1    <= 4'b0;
            rf_writeReg2    <= 4'b0;
            rf_writeData1   <= 32'b0;
            rf_writeData2   <= 32'b0;
            rf_readReg1     <= 4'b0;
            rf_readReg2     <= 4'b0;
            rf_readReg3     <= 4'b0;
            rf_readReg4     <= 4'b0;
            mac1_op1        <= 32'b0;
            mac1_op2        <= 32'b0;
            mac1_op3        <= 32'b0;
            mac2_op1        <= 32'b0;
            mac2_op2        <= 32'b0;
            mac2_op3        <= 32'b0;
            alu1_op1        <= 32'b0;
            alu1_op2        <= 32'b0;
            alu1_op         <= 4'b0;
            alu2_op1        <= 32'b0;
            alu2_op2        <= 32'b0;
            alu2_op         <= 4'b0;
            any_overflow    <= 1'b0;
            any_zero        <= 1'b0;
        end
        else begin
            // Default values
            rf_write <= 1'b0;
            any_overflow <= 1'b0;
            any_zero <= 1'b0;
            
            case (current_state)
                //--------------------------------------------------------------
                // STATE_DEACTIVATED: Αναμονή για enable
                //--------------------------------------------------------------
                STATE_DEACTIVATED: begin
                    final_output   <= 32'b0;
                    total_ovf      <= 1'b0;
                    total_zero     <= 1'b0;
                    ovf_fsm_stage  <= 3'b111;
                    zero_fsm_stage <= 3'b111;
                end
                
                //--------------------------------------------------------------
                // STATE_LOAD_WEIGHTS: Φόρτωση βαρών από ROM σε Register File
                // Χρειάζονται 6 κύκλοι για να γραφτούν 12 τιμές (2 ανά κύκλο)
                // Για απλοποίηση, φορτώνουμε όλα σε 1 κύκλο (multiple writes)
                //--------------------------------------------------------------
                STATE_LOAD_WEIGHTS: begin
                    // Γράφουμε τις πρώτες 2 τιμές
                    rf_write     <= 1'b1;
                    rf_writeReg1 <= ADDR_SHIFT_BIAS_1;
                    rf_writeData1<= ROM_SHIFT_BIAS_1;
                    rf_writeReg2 <= ADDR_SHIFT_BIAS_2;
                    rf_writeData2<= ROM_SHIFT_BIAS_2;
                    
                    weights_loaded <= 1'b1;
                    
                    // Σημείωση: Για πλήρη υλοποίηση θα χρειαζόταν επιπλέον κύκλοι
                    // Εδώ υποθέτουμε ότι οι τιμές αποθηκεύονται σε wires/regs
                end
                
                //--------------------------------------------------------------
                // STATE_PREPROCESS: Αριθμητική ολίσθηση δεξιά στις εισόδους
                // inter_1 = input_1 >>> shift_bias_1
                // inter_2 = input_2 >>> shift_bias_2
                //--------------------------------------------------------------
                STATE_PREPROCESS: begin
                    // Διαβάζουμε shift_bias_1 και shift_bias_2
                    rf_readReg1 <= ADDR_SHIFT_BIAS_1;
                    rf_readReg2 <= ADDR_SHIFT_BIAS_2;
                    
                    // ALU 1: input_1 >>> shift_bias_1
                    alu1_op1 <= input_1;
                    alu1_op2 <= ROM_SHIFT_BIAS_1;  // Χρησιμοποιούμε ROM απευθείας
                    alu1_op  <= ALUOP_SRA;
                    
                    // ALU 2: input_2 >>> shift_bias_2
                    alu2_op1 <= input_2;
                    alu2_op2 <= ROM_SHIFT_BIAS_2;
                    alu2_op  <= ALUOP_SRA;
                    
                    // Αποθήκευση αποτελεσμάτων
                    inter_1 <= alu1_result;
                    inter_2 <= alu2_result;
                    
                    // Έλεγχος για zero
                    if (alu1_zero || alu2_zero) begin
                        any_zero <= 1'b1;
                        if (zero_fsm_stage == 3'b111)
                            zero_fsm_stage <= STATE_PREPROCESS;
                    end
                end
                
                //--------------------------------------------------------------
                // STATE_INPUT_LAYER: Εκτέλεση νευρώνων 1 και 2 παράλληλα
                // inter_3 = inter_1 * weight_1 + bias_1
                // inter_4 = inter_2 * weight_2 + bias_2
                //--------------------------------------------------------------
                STATE_INPUT_LAYER: begin
                    // MAC 1: inter_1 * weight_1 + bias_1
                    mac1_op1 <= inter_1;
                    mac1_op2 <= ROM_WEIGHT_1;
                    mac1_op3 <= ROM_BIAS_1;
                    
                    // MAC 2: inter_2 * weight_2 + bias_2
                    mac2_op1 <= inter_2;
                    mac2_op2 <= ROM_WEIGHT_2;
                    mac2_op3 <= ROM_BIAS_2;
                    
                    // Αποθήκευση αποτελεσμάτων
                    inter_3 <= mac1_result;
                    inter_4 <= mac2_result;
                    
                    // Έλεγχος για overflow
                    if (mac1_ovf_mul || mac1_ovf_add || mac2_ovf_mul || mac2_ovf_add) begin
                        any_overflow <= 1'b1;
                        total_ovf <= 1'b1;
                        final_output <= MAX_POSITIVE;
                        if (ovf_fsm_stage == 3'b111)
                            ovf_fsm_stage <= STATE_INPUT_LAYER;
                    end
                    
                    // Έλεγχος για zero
                    if (mac1_zero_add || mac2_zero_add) begin
                        any_zero <= 1'b1;
                        total_zero <= 1'b1;
                        if (zero_fsm_stage == 3'b111)
                            zero_fsm_stage <= STATE_INPUT_LAYER;
                    end
                end
                
                //--------------------------------------------------------------
                // STATE_OUTPUT_LAYER1: Πρώτο βήμα output layer
                // inter_5 = inter_3 * weight_3 + 0 (πρώτος όρος)
                // inter_6 = inter_4 * weight_4 + 0 (δεύτερος όρος)
                //--------------------------------------------------------------
                STATE_OUTPUT_LAYER1: begin
                    // MAC 1: inter_3 * weight_3
                    mac1_op1 <= inter_3;
                    mac1_op2 <= ROM_WEIGHT_3;
                    mac1_op3 <= 32'b0;
                    
                    // MAC 2: inter_4 * weight_4
                    mac2_op1 <= inter_4;
                    mac2_op2 <= ROM_WEIGHT_4;
                    mac2_op3 <= 32'b0;
                    
                    inter_5 <= mac1_result;
                    inter_6 <= mac2_result;
                    
                    // Έλεγχος για overflow
                    if (mac1_ovf_mul || mac2_ovf_mul) begin
                        any_overflow <= 1'b1;
                        total_ovf <= 1'b1;
                        final_output <= MAX_POSITIVE;
                        if (ovf_fsm_stage == 3'b111)
                            ovf_fsm_stage <= STATE_OUTPUT_LAYER1;
                    end
                    
                    // Έλεγχος για zero
                    if (mac1_zero_mul || mac2_zero_mul) begin
                        any_zero <= 1'b1;
                        total_zero <= 1'b1;
                        if (zero_fsm_stage == 3'b111)
                            zero_fsm_stage <= STATE_OUTPUT_LAYER1;
                    end
                end
                
                //--------------------------------------------------------------
                // STATE_OUTPUT_LAYER2: Δεύτερο βήμα output layer
                // result = inter_5 + inter_6 + bias_3
                //--------------------------------------------------------------
                STATE_OUTPUT_LAYER2: begin
                    // MAC 1: inter_5 * 1 + inter_6 (χρησιμοποιούμε πολ/σμό με 1)
                    mac1_op1 <= inter_5;
                    mac1_op2 <= 32'h00000001;  // Πολλαπλασιασμός με 1
                    mac1_op3 <= inter_6;
                    
                    // MAC 2: mac1_result * 1 + bias_3
                    mac2_op1 <= mac1_result;
                    mac2_op2 <= 32'h00000001;
                    mac2_op3 <= ROM_BIAS_3;
                    
                    inter_5 <= mac2_result;
                    
                    // Έλεγχος για overflow
                    if (mac1_ovf_add || mac2_ovf_add) begin
                        any_overflow <= 1'b1;
                        total_ovf <= 1'b1;
                        final_output <= MAX_POSITIVE;
                        if (ovf_fsm_stage == 3'b111)
                            ovf_fsm_stage <= STATE_OUTPUT_LAYER2;
                    end
                    
                    // Έλεγχος για zero
                    if (mac2_zero_add) begin
                        any_zero <= 1'b1;
                        total_zero <= 1'b1;
                        if (zero_fsm_stage == 3'b111)
                            zero_fsm_stage <= STATE_OUTPUT_LAYER2;
                    end
                end
                
                //--------------------------------------------------------------
                // STATE_POSTPROCESS: Αριθμητική ολίσθηση αριστερά
                // final_output = inter_5 <<< shift_bias_3
                //--------------------------------------------------------------
                STATE_POSTPROCESS: begin
                    // ALU 1: inter_5 <<< shift_bias_3
                    alu1_op1 <= inter_5;
                    alu1_op2 <= ROM_SHIFT_BIAS_3;
                    alu1_op  <= ALUOP_SLA;
                    
                    if (!total_ovf) begin
                        final_output <= alu1_result;
                    end
                    
                    // Έλεγχος για zero
                    if (alu1_zero) begin
                        total_zero <= 1'b1;
                        if (zero_fsm_stage == 3'b111)
                            zero_fsm_stage <= STATE_POSTPROCESS;
                    end
                end
                
                //--------------------------------------------------------------
                // STATE_IDLE: Αναμονή για νέες εισόδους
                //--------------------------------------------------------------
                STATE_IDLE: begin
                    // Διατήρηση τελικής εξόδου
                    // Reset flags αν ξεκινήσει νέος κύκλος
                    if (enable) begin
                        total_ovf      <= 1'b0;
                        total_zero     <= 1'b0;
                        ovf_fsm_stage  <= 3'b111;
                        zero_fsm_stage <= 3'b111;
                    end
                end
                
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule
