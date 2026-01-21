//==============================================================================
// Neural Network Module - Άσκηση 4
// Νευρωνικό Δίκτυο 3 Νευρώνων με Έλεγχο FSM
//==============================================================================

module nn (
    input  wire        clk,             // System clock
    input  wire        resetn,          // Async active-low reset
    input  wire        enable,          // Enable signal
    input  wire [31:0] input_1,         // First input
    input  wire [31:0] input_2,         // Second input
    output reg  [31:0] final_output,    // System output
    output reg         total_ovf,       // Overflow indicator
    output reg         total_zero,      // Zero result indicator
    output reg  [2:0]  ovf_fsm_stage,   // Stage where overflow occurred
    output reg  [2:0]  zero_fsm_stage   // Stage where zero occurred
);

    //==========================================================================
    // Ορισμοί Κατάστάσεων FSM (Διαδοχική Κωδικοποίηση 3-bit):
    // S0 → S1 → S2(IDLE) → S3 → S4 → S5a → S5b → S6 → S2
    //==========================================================================
    localparam [2:0] S_DEACTIVATED   = 3'b000;  // S0: Αρχική/κατάσταση επαναφοράς
    localparam [2:0] S_LOADING       = 3'b001;  // S1: Φόρτωση βαρών από ROM στο RegFile
    localparam [2:0] S_IDLE          = 3'b010;  // S2: Έτοιμο - αναμονή enable
    localparam [2:0] S_PREPROCESS    = 3'b011;  // S3: Αριθμητική ολίσθηση δεξιά εισόδων
    localparam [2:0] S_INPUT_LAYER   = 3'b100;  // S4: Νευρώνες 1 & 2 (παράλληλα MAC)
    localparam [2:0] S_OUTPUT_LAYER1 = 3'b101;  // S5a: Νευρώνας 3 - πρώτο MAC (inter_3*w3+b3)
    localparam [2:0] S_OUTPUT_LAYER2 = 3'b110;  // S5b: Νευρώνας 3 - δεύτερο MAC (inter_4*w4+temp)
    localparam [2:0] S_POSTPROCESS   = 3'b111;  // S6: Αριθμητική ολίσθηση αριστερά εξόδου

    //==========================================================================
    // Κωδικοί Λειτουργίας ALU
    //==========================================================================
    localparam [3:0] ALUOP_SRA = 4'b0010;
    localparam [3:0] ALUOP_SLA = 4'b0011;

    //==========================================================================
    // Διευθύνσεις Register File
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
    // Constants
    //==========================================================================
    localparam [31:0] OVERFLOW_VALUE = 32'hFFFFFFFF; // Σύμφωνα με το reference model nn_model
    localparam [2:0]  NO_OVERFLOW    = 3'b111;
    localparam [2:0]  NO_ZERO        = 3'b111;

    //==========================================================================
    // State Registers
    //==========================================================================
    reg [2:0] state, next_state;
    reg       weights_loaded;      // Flag: βάρη ήδη φορτωμένα

    //==========================================================================
    // Μετρητής Φόρτωσης (για μεταφορά ROM σε RegFile)
    //==========================================================================
    reg [2:0] load_counter;
    localparam [2:0] LOAD_CYCLES = 3'd5;  // 5 κύκλοι για φόρτωση όλων των βαρών (2 ανά κύκλο)

    //==========================================================================
    // Ενδιάμεσοι Καταχωρητές (για αποθήκευση αποτελεσμάτων μεταξύ σταδίων FSM)
    //==========================================================================
    reg [31:0] inter_1, inter_2;   // Μετά την προ-επεξεργασία
    reg [31:0] inter_3, inter_4;   // Μετά το input layer
    reg [31:0] inter_5;            // Μετά το output layer
    reg [31:0] mac1_temp;          // Προσωρινή αποθήκευση αποτελέσματος MAC1 στο output layer

    //==========================================================================
    // ROM Interface Signals
    //==========================================================================
    reg  [7:0]  rom_addr1, rom_addr2;
    wire [31:0] rom_data1, rom_data2;

    //==========================================================================
    // Register File Interface Signals
    //==========================================================================
    reg  [3:0]  rf_readReg1, rf_readReg2, rf_readReg3, rf_readReg4;
    reg  [3:0]  rf_writeReg1, rf_writeReg2;
    reg  [31:0] rf_writeData1, rf_writeData2;
    reg         rf_write;
    wire [31:0] rf_readData1, rf_readData2, rf_readData3, rf_readData4;

    //==========================================================================
    // ALU Interface Signals (2 ALUs for shift operations)
    //==========================================================================
    reg  [31:0] alu1_op1, alu1_op2;
    reg  [3:0]  alu1_op;
    wire [31:0] alu1_result;
    wire        alu1_zero, alu1_ovf;

    reg  [31:0] alu2_op1, alu2_op2;
    reg  [3:0]  alu2_op;
    wire [31:0] alu2_result;
    wire        alu2_zero, alu2_ovf;

    //==========================================================================
    // MAC Interface Signals (2 MACs for neuron operations)
    //==========================================================================
    reg  [31:0] mac1_op1, mac1_op2, mac1_op3;
    wire [31:0] mac1_result;
    wire        mac1_zero_mul, mac1_zero_add, mac1_ovf_mul, mac1_ovf_add;

    reg  [31:0] mac2_op1, mac2_op2, mac2_op3;
    wire [31:0] mac2_result;
    wire        mac2_zero_mul, mac2_zero_add, mac2_ovf_mul, mac2_ovf_add;

    //==========================================================================
    // Overflow and Zero Detection
    //==========================================================================
    wire stage_overflow;
    wire stage_zero;

    //==========================================================================
    // Integration of Components
    //==========================================================================

    // ROM Instance
    WEIGHT_BIAS_MEMORY #(.DATAWIDTH(32)) rom_inst (
        .clk   (clk),
        .addr1 (rom_addr1),
        .addr2 (rom_addr2),
        .dout1 (rom_data1),
        .dout2 (rom_data2)
    );

    // Register File Instance
    regfile #(.DATAWIDTH(32)) regfile_inst (
        .clk        (clk),
        .resetn     (resetn),
        .readReg1   (rf_readReg1),
        .readReg2   (rf_readReg2),
        .readReg3   (rf_readReg3),
        .readReg4   (rf_readReg4),
        .writeReg1  (rf_writeReg1),
        .writeReg2  (rf_writeReg2),
        .writeData1 (rf_writeData1),
        .writeData2 (rf_writeData2),
        .write      (rf_write),
        .readData1  (rf_readData1),
        .readData2  (rf_readData2),
        .readData3  (rf_readData3),
        .readData4  (rf_readData4)
    );

    // ALU 1 Instance
    alu alu1_inst (
        .op1    (alu1_op1),
        .op2    (alu1_op2),
        .alu_op (alu1_op),
        .zero   (alu1_zero),
        .result (alu1_result),
        .ovf    (alu1_ovf)
    );

    // ALU 2 Instance
    alu alu2_inst (
        .op1    (alu2_op1),
        .op2    (alu2_op2),
        .alu_op (alu2_op),
        .zero   (alu2_zero),
        .result (alu2_result),
        .ovf    (alu2_ovf)
    );

    // MAC 1 Instance
    mac_unit mac1_inst (
        .op1          (mac1_op1),
        .op2          (mac1_op2),
        .op3          (mac1_op3),
        .total_result (mac1_result),
        .zero_mul     (mac1_zero_mul),
        .zero_add     (mac1_zero_add),
        .ovf_mul      (mac1_ovf_mul),
        .ovf_add      (mac1_ovf_add)
    );

    // MAC 2 Instance
    mac_unit mac2_inst (
        .op1          (mac2_op1),
        .op2          (mac2_op2),
        .op3          (mac2_op3),
        .total_result (mac2_result),
        .zero_mul     (mac2_zero_mul),
        .zero_add     (mac2_zero_add),
        .ovf_mul      (mac2_ovf_mul),
        .ovf_add      (mac2_ovf_add)
    );

    //==========================================================================
    // Κατάσταση FSM (ασύγχρονο reset, συγχρονισμένη μετάβαση)
    //==========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= S_DEACTIVATED;
        end
        else begin
            state <= next_state;
        end
    end

    //==========================================================================
    // FSM Next State Logic (Combinational)
    //==========================================================================
    always @(*) begin
        next_state = state;  // Default: παραμονή στην τρέχουσα κατάσταση

        case (state)
            S_DEACTIVATED: begin
                if (enable) begin
                    if (weights_loaded)
                        next_state = S_PREPROCESS;
                    else
                        next_state = S_LOADING;
                end
            end

            S_LOADING: begin
                if (load_counter >= LOAD_CYCLES)
                    next_state = S_IDLE;
            end

            S_IDLE: begin
                if (enable)
                    next_state = S_PREPROCESS;
            end

            S_PREPROCESS: begin
                // Έλεγχος υπερχείλισης στις πράξεις ολίσθησης
                if (alu1_ovf || alu2_ovf)
                    next_state = S_IDLE;
                else
                    next_state = S_INPUT_LAYER;
            end

            S_INPUT_LAYER: begin
                // Έλεγχος υπερχείλισης στις πράξεις MAC του input layer
                if (mac1_ovf_mul || mac1_ovf_add || mac2_ovf_mul || mac2_ovf_add)
                    next_state = S_IDLE;
                else
                    next_state = S_OUTPUT_LAYER1;
            end

            S_OUTPUT_LAYER1: begin
                // Έλεγχος υπερχείλισης στην πράξη MAC1 (inter_3 * weight_3 + bias_3)
                if (mac1_ovf_mul || mac1_ovf_add)
                    next_state = S_IDLE;
                else
                    next_state = S_OUTPUT_LAYER2;
            end

            S_OUTPUT_LAYER2: begin
                // Έλεγχος υπερχείλισης στην πράξη MAC2 (inter_4 * weight_4 + mac1_temp)
                if (mac2_ovf_mul || mac2_ovf_add)
                    next_state = S_IDLE;
                else
                    next_state = S_POSTPROCESS;
            end

            S_POSTPROCESS: begin
                // Επιστροφή σε IDLE
                next_state = S_IDLE;
            end

            default: next_state = S_DEACTIVATED;
        endcase
    end

    //==========================================================================
    // Loading Counter Logic
    //==========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            load_counter <= 3'd0;
            weights_loaded <= 1'b0;
        end
        else begin
            if (state == S_LOADING) begin
                if (load_counter < LOAD_CYCLES)
                    load_counter <= load_counter + 1'b1;
                else
                    weights_loaded <= 1'b1;
            end
            else if (state == S_DEACTIVATED && !enable) begin
                // Επαναφορά μετρητή κατά την απενεργοποίηση
                load_counter <= 3'd0;
            end
        end
    end

    //==========================================================================
    // Έλεγχος Διευθύνσεων ROM
    //==========================================================================
    always @(*) begin
        rom_addr1 = 8'd0;
        rom_addr2 = 8'd0;

        if (state == S_LOADING) begin
            case (load_counter)
                3'd0: begin
                    rom_addr1 = 8'd8;   // shift_bias_1
                    rom_addr2 = 8'd12;  // shift_bias_2
                end
                3'd1: begin
                    rom_addr1 = 8'd16;  // weight_1
                    rom_addr2 = 8'd20;  // bias_1
                end
                3'd2: begin
                    rom_addr1 = 8'd24;  // weight_2
                    rom_addr2 = 8'd28;  // bias_2
                end
                3'd3: begin
                    rom_addr1 = 8'd32;  // weight_3
                    rom_addr2 = 8'd36;  // weight_4
                end
                3'd4: begin
                    rom_addr1 = 8'd40;  // bias_3
                    rom_addr2 = 8'd44;  // shift_bias_3
                end
                default: begin
                    rom_addr1 = 8'd0;
                    rom_addr2 = 8'd0;
                end
            endcase
        end
    end

    //==========================================================================
    // Έλεγχος Εγγραφής στο Register File
    //==========================================================================
    always @(*) begin
        rf_write = 1'b0;
        rf_writeReg1 = 4'd0;
        rf_writeReg2 = 4'd0;
        rf_writeData1 = 32'd0;
        rf_writeData2 = 32'd0;

        if (state == S_LOADING && load_counter > 0 && load_counter <= LOAD_CYCLES) begin
            rf_write = 1'b1;
            case (load_counter)
                3'd1: begin
                    rf_writeReg1 = ADDR_SHIFT_BIAS_1;  // 0x2
                    rf_writeReg2 = ADDR_SHIFT_BIAS_2;  // 0x3
                    rf_writeData1 = rom_data1;
                    rf_writeData2 = rom_data2;
                end
                3'd2: begin
                    rf_writeReg1 = ADDR_WEIGHT_1;      // 0x4
                    rf_writeReg2 = ADDR_BIAS_1;        // 0x5
                    rf_writeData1 = rom_data1;
                    rf_writeData2 = rom_data2;
                end
                3'd3: begin
                    rf_writeReg1 = ADDR_WEIGHT_2;      // 0x6
                    rf_writeReg2 = ADDR_BIAS_2;        // 0x7
                    rf_writeData1 = rom_data1;
                    rf_writeData2 = rom_data2;
                end
                3'd4: begin
                    rf_writeReg1 = ADDR_WEIGHT_3;      // 0x8
                    rf_writeReg2 = ADDR_WEIGHT_4;      // 0x9
                    rf_writeData1 = rom_data1;
                    rf_writeData2 = rom_data2;
                end
                3'd5: begin
                    rf_writeReg1 = ADDR_BIAS_3;        // 0xA
                    rf_writeReg2 = ADDR_SHIFT_BIAS_3;  // 0xB
                    rf_writeData1 = rom_data1;
                    rf_writeData2 = rom_data2;
                end
                default: rf_write = 1'b0;
            endcase
        end
    end

    //==========================================================================
    // Έλεγχος Διευθύνσεων Ανάγνωσης Register File
    // Pre-Fetching: S_IDLE → S_PREPROCESS → S_INPUT_LAYER → S_OUTPUT_LAYER → S_POSTPROCESS
    //==========================================================================
    always @(*) begin
        rf_readReg1 = 4'd0;
        rf_readReg2 = 4'd0;
        rf_readReg3 = 4'd0;
        rf_readReg4 = 4'd0;

        case (state)
            // Στο IDLE/DEACTIVATED θέτουμε τις διευθύνσεις για PREPROCESS
            S_IDLE, S_DEACTIVATED: begin
                rf_readReg1 = ADDR_SHIFT_BIAS_1;  // Θα διαβαστεί στο S_PREPROCESS
                rf_readReg2 = ADDR_SHIFT_BIAS_2;
            end

            // Στο PREPROCESS θέτουμε τις διευθύνσεις για INPUT_LAYER
            S_PREPROCESS: begin
                rf_readReg1 = ADDR_WEIGHT_1;      // Θα διαβαστεί στο S_INPUT_LAYER
                rf_readReg2 = ADDR_BIAS_1;
                rf_readReg3 = ADDR_WEIGHT_2;
                rf_readReg4 = ADDR_BIAS_2;
            end

            // Στο INPUT_LAYER θέτουμε τις διευθύνσεις για OUTPUT_LAYER1
            S_INPUT_LAYER: begin
                rf_readReg1 = ADDR_WEIGHT_3;      // Θα διαβαστεί στο S_OUTPUT_LAYER1
                rf_readReg2 = ADDR_BIAS_3;
            end

            // Στο OUTPUT_LAYER1 θέτουμε τις διευθύνσεις για OUTPUT_LAYER2
            S_OUTPUT_LAYER1: begin
                rf_readReg1 = ADDR_WEIGHT_4;      // Θα διαβαστεί στο S_OUTPUT_LAYER2
            end

            // Στο OUTPUT_LAYER2 θέτουμε τις διευθύνσεις για POSTPROCESS
            S_OUTPUT_LAYER2: begin
                rf_readReg1 = ADDR_SHIFT_BIAS_3;  // Θα διαβαστεί στο S_POSTPROCESS
            end

            default: begin
                rf_readReg1 = 4'd0;
                rf_readReg2 = 4'd0;
                rf_readReg3 = 4'd0;
                rf_readReg4 = 4'd0;
            end
        endcase
    end

    //==========================================================================
    // Έλεγχος Εισόδων ALU
    //==========================================================================
    always @(*) begin
        alu1_op1 = 32'd0;
        alu1_op2 = 32'd0;
        alu1_op  = ALUOP_SRA;
        alu2_op1 = 32'd0;
        alu2_op2 = 32'd0;
        alu2_op  = ALUOP_SRA;

        case (state)
            S_PREPROCESS: begin
                // Αριθμητική ολίσθηση δεξιά: inter_1 = input_1 >>> shift_bias_1
                alu1_op1 = input_1;
                alu1_op2 = rf_readData1;  // shift_bias_1
                alu1_op  = ALUOP_SRA;
                
                // Αριθμητική ολίσθηση δεξιά: inter_2 = input_2 >>> shift_bias_2
                alu2_op1 = input_2;
                alu2_op2 = rf_readData2;  // shift_bias_2
                alu2_op  = ALUOP_SRA;
            end

            S_POSTPROCESS: begin
                // Αριθμητική ολίσθηση αριστερά: output = inter_5 <<< shift_bias_3
                alu1_op1 = inter_5;
                alu1_op2 = rf_readData1;  // shift_bias_3
                alu1_op  = ALUOP_SLA;
            end

            default: begin
                alu1_op1 = 32'd0;
                alu1_op2 = 32'd0;
                alu2_op1 = 32'd0;
                alu2_op2 = 32'd0;
            end
        endcase
    end

    //==========================================================================
    // Έλεγχος Εισόδων MAC
    //==========================================================================
    always @(*) begin
        mac1_op1 = 32'd0;
        mac1_op2 = 32'd0;
        mac1_op3 = 32'd0;
        mac2_op1 = 32'd0;
        mac2_op2 = 32'd0;
        mac2_op3 = 32'd0;

        case (state)
            S_INPUT_LAYER: begin
                // MAC1: inter_3 = inter_1 * weight_1 + bias_1
                mac1_op1 = inter_1;
                mac1_op2 = rf_readData1;  // weight_1
                mac1_op3 = rf_readData2;  // bias_1
                
                // MAC2: inter_4 = inter_2 * weight_2 + bias_2
                mac2_op1 = inter_2;
                mac2_op2 = rf_readData3;  // weight_2
                mac2_op3 = rf_readData4;  // bias_2
            end

            S_OUTPUT_LAYER1: begin
                // MAC1: mac1_temp = inter_3 * weight_3 + bias_3
                mac1_op1 = inter_3;
                mac1_op2 = rf_readData1;  // weight_3
                mac1_op3 = rf_readData2;  // bias_3
            end

            S_OUTPUT_LAYER2: begin
                // MAC2: inter_5 = inter_4 * weight_4 + mac1_temp
                mac2_op1 = inter_4;
                mac2_op2 = rf_readData1;  // weight_4
                mac2_op3 = mac1_temp;     // registered result από τον προηγούμενο κύκλο
            end

            default: begin
                mac1_op1 = 32'd0;
                mac1_op2 = 32'd0;
                mac1_op3 = 32'd0;
                mac2_op1 = 32'd0;
                mac2_op2 = 32'd0;
                mac2_op3 = 32'd0;
            end
        endcase
    end

    //==========================================================================
    // Αποθήκευση Ενδιάμεσων Αποτελεσμάτων
    //==========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            inter_1   <= 32'd0;
            inter_2   <= 32'd0;
            inter_3   <= 32'd0;
            inter_4   <= 32'd0;
            inter_5   <= 32'd0;
            mac1_temp <= 32'd0;
        end
        else begin
            case (state)
                S_PREPROCESS: begin
                    if (!alu1_ovf && !alu2_ovf) begin
                        inter_1 <= alu1_result;
                        inter_2 <= alu2_result;
                    end
                end

                S_INPUT_LAYER: begin
                    if (!(mac1_ovf_mul || mac1_ovf_add || mac2_ovf_mul || mac2_ovf_add)) begin
                        inter_3 <= mac1_result;
                        inter_4 <= mac2_result;
                    end
                end

                S_OUTPUT_LAYER1: begin
                    // Αποθήκευση του MAC1 result σε register (σπάει το combinatorial loop)
                    if (!(mac1_ovf_mul || mac1_ovf_add)) begin
                        mac1_temp <= mac1_result;  // inter_3 * weight_3 + bias_3
                    end
                end

                S_OUTPUT_LAYER2: begin
                    // Χρησιμοποιεί το mac1_temp (registered) από τον προηγούμενο κύκλο
                    if (!(mac2_ovf_mul || mac2_ovf_add)) begin
                        inter_5 <= mac2_result;    // inter_4 * weight_4 + mac1_temp
                    end
                end

                S_DEACTIVATED: begin
                    // Μηδενισμός ενδιάμεσων κατά την επαναφορά/απενεργοποίηση
                    inter_1   <= 32'd0;
                    inter_2   <= 32'd0;
                    inter_3   <= 32'd0;
                    inter_4   <= 32'd0;
                    inter_5   <= 32'd0;
                    mac1_temp <= 32'd0;
                end

                default: begin
                    // Διατήρηση τρέχουσας τιμής
                end
            endcase
        end
    end

    //==========================================================================
    // Output Logic (Moore FSM - οι έξοδοι εξαρτώνται μόνο από την κατάσταση)
    //==========================================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            final_output   <= 32'd0;
            total_ovf      <= 1'b0;
            total_zero     <= 1'b0;
            ovf_fsm_stage  <= NO_OVERFLOW;
            zero_fsm_stage <= NO_ZERO;
        end
        else begin
            case (state)
                S_DEACTIVATED: begin
                    final_output   <= 32'd0;
                    total_ovf      <= 1'b0;
                    total_zero     <= 1'b0;
                    ovf_fsm_stage  <= NO_OVERFLOW;
                    zero_fsm_stage <= NO_ZERO;
                end

                S_LOADING, S_IDLE: begin
                    // Διατήρηση προηγούμενης εξόδου κατά τη φόρτωση/αναμονή
                end

                S_PREPROCESS: begin
                    if (alu1_ovf || alu2_ovf) begin
                        final_output  <= OVERFLOW_VALUE;
                        total_ovf     <= 1'b1;
                        ovf_fsm_stage <= S_PREPROCESS;
                    end
                    if (alu1_zero || alu2_zero) begin
                        total_zero     <= 1'b1;
                        zero_fsm_stage <= S_PREPROCESS;
                    end
                end

                S_INPUT_LAYER: begin
                    if (mac1_ovf_mul || mac1_ovf_add || mac2_ovf_mul || mac2_ovf_add) begin
                        final_output  <= OVERFLOW_VALUE;
                        total_ovf     <= 1'b1;
                        ovf_fsm_stage <= S_INPUT_LAYER;
                    end
                    if (mac1_zero_add || mac2_zero_add) begin
                        total_zero     <= 1'b1;
                        zero_fsm_stage <= S_INPUT_LAYER;
                    end
                end

                S_OUTPUT_LAYER1: begin
                    if (mac1_ovf_mul || mac1_ovf_add) begin
                        final_output  <= OVERFLOW_VALUE;
                        total_ovf     <= 1'b1;
                        ovf_fsm_stage <= S_OUTPUT_LAYER1;
                    end
                    if (mac1_zero_add) begin
                        total_zero     <= 1'b1;
                        zero_fsm_stage <= S_OUTPUT_LAYER1;
                    end
                end

                S_OUTPUT_LAYER2: begin
                    if (mac2_ovf_mul || mac2_ovf_add) begin
                        final_output  <= OVERFLOW_VALUE;
                        total_ovf     <= 1'b1;
                        ovf_fsm_stage <= S_OUTPUT_LAYER2;
                    end
                    if (mac2_zero_add) begin
                        total_zero     <= 1'b1;
                        zero_fsm_stage <= S_OUTPUT_LAYER2;
                    end
                end

                S_POSTPROCESS: begin
                    if (alu1_ovf) begin
                        final_output  <= OVERFLOW_VALUE;
                        total_ovf     <= 1'b1;
                        ovf_fsm_stage <= S_POSTPROCESS;
                    end
                    else begin
                        final_output <= alu1_result;
                    end
                    if (alu1_zero) begin
                        total_zero     <= 1'b1;
                        zero_fsm_stage <= S_POSTPROCESS;
                    end
                end

                default: begin
                    final_output <= 32'd0;
                end
            endcase
        end
    end

endmodule
