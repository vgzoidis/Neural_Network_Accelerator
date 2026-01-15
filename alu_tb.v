`timescale 1ns / 1ps

module alu_tb;

    // 1. Δήλωση σημάτων για σύνδεση με το Module (UUT)
    reg signed [31:0] op1;      // Χρησιμοποιούμε signed για να βλέπουμε σωστά τα νούμερα στο log
    reg signed [31:0] op2;
    reg [3:0] alu_op;
    
    wire zero;
    wire signed [31:0] result;
    wire ovf;

    // 2. Ορισμός Παραμέτρων (ίδιες με το alu.v για ευκολία)
    parameter [3:0] ALUOP_AND   = 4'b1000;
    parameter [3:0] ALUOP_OR    = 4'b1001;
    parameter [3:0] ALUOP_NOR   = 4'b1010;
    parameter [3:0] ALUOP_NAND  = 4'b1011;
    parameter [3:0] ALUOP_XOR   = 4'b1100;
    parameter [3:0] ALUOP_ADD   = 4'b0100;
    parameter [3:0] ALUOP_SUB   = 4'b0101;
    parameter [3:0] ALUOP_MULT  = 4'b0110;
    parameter [3:0] ALUOP_SRL   = 4'b0000;
    parameter [3:0] ALUOP_SLL   = 4'b0001;
    parameter [3:0] ALUOP_SRA   = 4'b0010;
    parameter [3:0] ALUOP_SLA   = 4'b0011;

    // 3. Instantiate the Unit Under Test (UUT)
    alu uut (
        .op1(op1), 
        .op2(op2), 
        .alu_op(alu_op), 
        .zero(zero), 
        .result(result), 
        .ovf(ovf)
    );

    // 4. Διαδικασία Ελέγχου
    initial begin
        // Ρύθμιση για εμφάνιση κυματομορφών στο EDA Playground
        $dumpfile("dump.vcd");
        $dumpvars(0, alu_tb);

        $display("Starting ALU Testbench...");
        $display("----------------------------------------------------------------");
        $display("Time | OP Code | OP Name |     Op1     |     Op2     |    Result   | OVF | Z |");
        $display("----------------------------------------------------------------");

        // --- TEST 1: ADDITION (Πρόσθεση) ---
        op1 = 15; op2 = 10; alu_op = ALUOP_ADD;
        #10; print_result("ADD ");

        // --- TEST 2: ADDITION OVERFLOW ---
        // Μέγιστος θετικός (2^31 - 1) + 1 => Πρέπει να βγάλει αρνητικό και OVF=1
        op1 = 32'h7FFFFFFF; op2 = 1; alu_op = ALUOP_ADD;
      #10; print_result("ADD(ovf check)");

        // --- TEST 3: SUBTRACTION (Αφαίρεση) ---
        op1 = 20; op2 = 30; alu_op = ALUOP_SUB; // 20 - 30 = -10
        #10; print_result("SUB ");

        // --- TEST 4: MULTIPLICATION (Πολλαπλασιασμός) ---
        op1 = 10; op2 = -5; alu_op = ALUOP_MULT; // 10 * -5 = -50
        #10; print_result("MULT");

        // --- TEST 5: LOGIC AND ---
        op1 = 32'hFFFF0000; op2 = 32'h00FFFF00; alu_op = ALUOP_AND;
        #10; print_result("AND ");

        // --- TEST 6: LOGIC XOR ---
        op1 = 32'h55555555; op2 = 32'hFFFFFFFF; alu_op = ALUOP_XOR;
        #10; print_result("XOR ");

        // --- TEST 7: LOGICAL SHIFT RIGHT (SRL) ---
        // Μετακίνηση του -16 (FFFFFFF0) δεξιά κατά 2. 
        // Λογική ολίσθηση -> γεμίζει με 0 -> γίνεται θετικός αριθμός.
        op1 = -16; op2 = 2; alu_op = ALUOP_SRL;
        #10; print_result("SRL ");

        // --- TEST 8: ARITHMETIC SHIFT RIGHT (SRA) ---
        // Μετακίνηση του -16 (FFFFFFF0) δεξιά κατά 2.
        // Αριθμητική ολίσθηση -> γεμίζει με 1 -> παραμένει αρνητικός (-4).
        op1 = -16; op2 = 2; alu_op = ALUOP_SRA;
        #10; print_result("SRA ");
        
        // --- TEST 9: ZERO FLAG ---
        op1 = 50; op2 = 50; alu_op = ALUOP_SUB; // 50-50 = 0
      #10; print_result("SUB(0 check)");

        $display("----------------------------------------------------------------");
        $finish;
    end

    // Βοηθητικό task για εκτύπωση αποτελεσμάτων στην κονσόλα
    task print_result;
        input [55:0] op_name; // String name for operation
        begin
            $display("%4t |  %b  | %s | %11d | %11d | %11d |  %b  | %b |", 
                     $time, alu_op, op_name, op1, op2, result, ovf, zero);
        end
    endtask

endmodule