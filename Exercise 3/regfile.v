//==============================================================================
// Register File Module - Άσκηση 3
// 16 x DATAWIDTH-bit Register File με 4 read ports και 2 write ports
//==============================================================================

module regfile #(
    parameter DATAWIDTH = 32    // Πλάτος δεδομένων (default 32 bits)
) (
    input  wire                  clk,        // Ρολόι
    input  wire                  resetn,     // Σήμα επαναφοράς (active low)
    input  wire [3:0]            readReg1,   // Διεύθυνση ανάγνωσης 1
    input  wire [3:0]            readReg2,   // Διεύθυνση ανάγνωσης 2
    input  wire [3:0]            readReg3,   // Διεύθυνση ανάγνωσης 3
    input  wire [3:0]            readReg4,   // Διεύθυνση ανάγνωσης 4
    input  wire [3:0]            writeReg1,  // Διεύθυνση εγγραφής 1
    input  wire [3:0]            writeReg2,  // Διεύθυνση εγγραφής 2
    input  wire [DATAWIDTH-1:0]  writeData1, // Δεδομένα εγγραφής 1
    input  wire [DATAWIDTH-1:0]  writeData2, // Δεδομένα εγγραφής 2
    input  wire                  write,      // Σήμα ελέγχου εγγραφής
    output reg  [DATAWIDTH-1:0]  readData1,  // Δεδομένα ανάγνωσης 1
    output reg  [DATAWIDTH-1:0]  readData2,  // Δεδομένα ανάγνωσης 2
    output reg  [DATAWIDTH-1:0]  readData3,  // Δεδομένα ανάγνωσης 3
    output reg  [DATAWIDTH-1:0]  readData4   // Δεδομένα ανάγνωσης 4
);

    //--------------------------------------------------------------------------
    // Πίνακας καταχωρητών 16 x DATAWIDTH bits
    //--------------------------------------------------------------------------
    reg [DATAWIDTH-1:0] registers [0:15];
    
    // Μεταβλητή για βρόχο
    integer i;

    //--------------------------------------------------------------------------
    // Λογική εγγραφής και ανάγνωσης
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Ασύγχρονη επαναφορά (active low) - Μηδενισμός όλων των καταχωρητών
            for (i = 0; i < 16; i = i + 1) begin
                registers[i] <= {DATAWIDTH{1'b0}};
            end
            // Μηδενισμός εξόδων
            readData1 <= {DATAWIDTH{1'b0}};
            readData2 <= {DATAWIDTH{1'b0}};
            readData3 <= {DATAWIDTH{1'b0}};
            readData4 <= {DATAWIDTH{1'b0}};
        end
        else begin
            //------------------------------------------------------------------
            // Λειτουργία εγγραφής
            //------------------------------------------------------------------
            if (write) begin
                registers[writeReg1] <= writeData1;
                registers[writeReg2] <= writeData2;
            end
            
            //------------------------------------------------------------------
            // Λειτουργία Ανάγνωσης με Προτεραιότητα Εγγραφής (Forwarding)
            // Ελέγχουμε αν γίνεται εγγραφή στην ίδια διεύθυνση που διαβάζουμε.
            // Αν ναι, δίνουμε το νέο δεδομένο (writeData), αλλιώς το αποθηκευμένο.
            //------------------------------------------------------------------
            
            // Port 1
            if (write && (readReg1 == writeReg1))      readData1 <= writeData1;
            else if (write && (readReg1 == writeReg2)) readData1 <= writeData2;
            else                                       readData1 <= registers[readReg1];

            // Port 2
            if (write && (readReg2 == writeReg1))      readData2 <= writeData1;
            else if (write && (readReg2 == writeReg2)) readData2 <= writeData2;
            else                                       readData2 <= registers[readReg2];

            // Port 3
            if (write && (readReg3 == writeReg1))      readData3 <= writeData1;
            else if (write && (readReg3 == writeReg2)) readData3 <= writeData2;
            else                                       readData3 <= registers[readReg3];

            // Port 4
            if (write && (readReg4 == writeReg1))      readData4 <= writeData1;
            else if (write && (readReg4 == writeReg2)) readData4 <= writeData2;
            else                                       readData4 <= registers[readReg4];
        end
    end

endmodule
