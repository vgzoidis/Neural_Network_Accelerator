//==============================================================================
// Calculator Encoder Module - Άσκηση 2
// Structural Verilog - Παραγωγή alu_op από btnl, btnr, btnd
// Βασισμένο στα Σχήματα 2-5 της εκφώνησης
//
// Εξισώσεις από τα σχήματα:
// alu_op[0] = (NOT(btnl) AND btnd) OR ((btnl AND btnr) AND NOT(btnd))  -- Σχ. 2
// alu_op[1] = btnl AND (NOT(btnr) OR NOT(btnd))                        -- Σχ. 3
// alu_op[2] = (NOT(btnl) AND btnr) OR (btnl AND NOT(btnr XOR btnd))    -- Σχ. 4
// alu_op[3] = (btnl AND btnr) OR (btnl AND btnd)                       -- Σχ. 5
//
// Πίνακας Αλήθειας:
// btnl btnr btnd | alu_op | Λειτουργία
// ----+----+----+---------+-----------
//  0    0    0  |  0000   | SRL
//  0    0    1  |  0001   | SLL
//  0    1    0  |  0100   | ADD
//  0    1    1  |  0101   | SUB
//  1    0    0  |  0110   | MULT
//  1    0    1  |  1010   | NOR
//  1    1    0  |  1011   | NAND
//  1    1    1  |  1100   | XOR
//==============================================================================

module calc_enc (
    input  wire btnl,           // Αριστερό πλήκτρο
    input  wire btnr,           // Δεξί πλήκτρο
    input  wire btnd,           // Κάτω πλήκτρο
    output wire [3:0] alu_op    // Κωδικός λειτουργίας ALU
);

    //--------------------------------------------------------------------------
    // Ενδιάμεσα σήματα - Αντεστραμμένες είσοδοι
    //--------------------------------------------------------------------------
    wire btnl_n;                // NOT(btnl)
    wire btnr_n;                // NOT(btnr)
    wire btnd_n;                // NOT(btnd)

    //--------------------------------------------------------------------------
    // Ενδιάμεσα σήματα για alu_op[0] - Σχ. 2
    // alu_op[0] = (NOT(btnl) AND btnd) OR ((btnl AND btnr) AND NOT(btnd))
    //--------------------------------------------------------------------------
    wire and0_left;             // NOT(btnl) AND btnd
    wire and0_right_inner;      // btnl AND btnr
    wire and0_right;            // (btnl AND btnr) AND NOT(btnd)

    //--------------------------------------------------------------------------
    // Ενδιάμεσα σήματα για alu_op[1] - Σχ. 3
    // alu_op[1] = btnl AND (NOT(btnr) OR NOT(btnd))
    //--------------------------------------------------------------------------
    wire or1_inner;             // NOT(btnr) OR NOT(btnd)

    //--------------------------------------------------------------------------
    // Ενδιάμεσα σήματα για alu_op[2] - Σχ. 4
    // alu_op[2] = (NOT(btnl) AND btnr) OR (btnl AND NOT(btnr XOR btnd))
    //--------------------------------------------------------------------------
    wire and2_left;             // NOT(btnl) AND btnr
    wire xor2;                  // btnr XOR btnd
    wire xor2_n;                // NOT(btnr XOR btnd)
    wire and2_right;            // btnl AND NOT(btnr XOR btnd)

    //--------------------------------------------------------------------------
    // Ενδιάμεσα σήματα για alu_op[3] - Σχ. 5
    // alu_op[3] = (btnl AND btnr) OR (btnl AND btnd)
    //--------------------------------------------------------------------------
    wire and3_left;             // btnl AND btnr
    wire and3_right;            // btnl AND btnd

    //--------------------------------------------------------------------------
    // NOT πύλες για τις αντεστραμμένες εισόδους
    //--------------------------------------------------------------------------
    not U_NOT_BTNL (btnl_n, btnl);
    not U_NOT_BTNR (btnr_n, btnr);
    not U_NOT_BTND (btnd_n, btnd);

    //--------------------------------------------------------------------------
    // alu_op[0] - Σχ. 2
    // alu_op[0] = (NOT(btnl) AND btnd) OR ((btnl AND btnr) AND NOT(btnd))
    //--------------------------------------------------------------------------
    and U_AND0_LEFT        (and0_left, btnl_n, btnd);
    and U_AND0_RIGHT_INNER (and0_right_inner, btnl, btnr);
    and U_AND0_RIGHT       (and0_right, and0_right_inner, btnd_n);
    or  U_OR0              (alu_op[0], and0_left, and0_right);

    //--------------------------------------------------------------------------
    // alu_op[1] - Σχ. 3
    // alu_op[1] = btnl AND (NOT(btnr) OR NOT(btnd))
    //--------------------------------------------------------------------------
    or  U_OR1_INNER (or1_inner, btnr_n, btnd_n);
    and U_AND1      (alu_op[1], btnl, or1_inner);

    //--------------------------------------------------------------------------
    // alu_op[2] - Σχ. 4
    // alu_op[2] = (NOT(btnl) AND btnr) OR (btnl AND NOT(btnr XOR btnd))
    //--------------------------------------------------------------------------
    and U_AND2_LEFT  (and2_left, btnl_n, btnr);
    xor U_XOR2       (xor2, btnr, btnd);
    not U_NOT_XOR2   (xor2_n, xor2);
    and U_AND2_RIGHT (and2_right, btnl, xor2_n);
    or  U_OR2        (alu_op[2], and2_left, and2_right);

    //--------------------------------------------------------------------------
    // alu_op[3] - Σχ. 5
    // alu_op[3] = (btnl AND btnr) OR (btnl AND btnd)
    //--------------------------------------------------------------------------
    and U_AND3_LEFT  (and3_left, btnl, btnr);
    and U_AND3_RIGHT (and3_right, btnl, btnd);
    or  U_OR3        (alu_op[3], and3_left, and3_right);

endmodule
