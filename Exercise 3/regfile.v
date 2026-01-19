//==============================================================================
// Register File Module - Άσκηση 3
// 16 x DATAWIDTH-bit Register File με 4 read ports και 2 write ports
// 
// Σύμφωνα με την εκφώνηση:
//   - "Μέσω ενός always block, θα γίνεται η εγγραφή ή ανάγνωση"
//   - "θεωρούμε ότι δεν μπορούμε να πραγματοποιήσουμε ταυτόχρονα ανάγνωση και εγγραφή"
//   - "Σε περίπτωση που η διεύθυνση εγγραφής είναι ίδια με διεύθυνση ανάγνωσης,
//      δώστε προτεραιότητα στην εγγραφή του writeData"
//
// Υλοποίηση:
//   - Σύγχρονη λειτουργία (registered read/write) σε posedge clk
//   - Ασύγχρονη επαναφορά (active low reset)
//   - Data forwarding: αν write=1 και readReg==writeReg, επιστρέφει writeData
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
    // Ένα always block για εγγραφή ή ανάγνωση (σύμφωνα με εκφώνηση)
    // 
    // Λογική:
    //   - Αν write=1: Εγγραφή δεδομένων + Forwarding στις εξόδους ανάγνωσης
    //   - Αν write=0: Ανάγνωση από τους καταχωρητές
    //   - Το forwarding εξασφαλίζει ότι αν γράφουμε σε διεύθυνση που διαβάζουμε,
    //     η έξοδος θα δείξει τα νέα δεδομένα (write-first behavior)
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Ασύγχρονη επαναφορά - Μηδενισμός όλων των καταχωρητών
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
            if (write) begin
                //--------------------------------------------------------------
                // Λειτουργία Εγγραφής
                //--------------------------------------------------------------
                registers[writeReg1] <= writeData1;
                registers[writeReg2] <= writeData2;
                
                //--------------------------------------------------------------
                // Forwarding: Αν η διεύθυνση ανάγνωσης == διεύθυνση εγγραφής,
                // επιστρέφουμε τα νέα δεδομένα (προτεραιότητα εγγραφής)
                //--------------------------------------------------------------
                // Port 1
                if (readReg1 == writeReg1)      readData1 <= writeData1;
                else if (readReg1 == writeReg2) readData1 <= writeData2;
                else                            readData1 <= registers[readReg1];

                // Port 2
                if (readReg2 == writeReg1)      readData2 <= writeData1;
                else if (readReg2 == writeReg2) readData2 <= writeData2;
                else                            readData2 <= registers[readReg2];

                // Port 3
                if (readReg3 == writeReg1)      readData3 <= writeData1;
                else if (readReg3 == writeReg2) readData3 <= writeData2;
                else                            readData3 <= registers[readReg3];

                // Port 4
                if (readReg4 == writeReg1)      readData4 <= writeData1;
                else if (readReg4 == writeReg2) readData4 <= writeData2;
                else                            readData4 <= registers[readReg4];
            end
            else begin
                //--------------------------------------------------------------
                // Λειτουργία Ανάγνωσης (write=0)
                //--------------------------------------------------------------
                readData1 <= registers[readReg1];
                readData2 <= registers[readReg2];
                readData3 <= registers[readReg3];
                readData4 <= registers[readReg4];
            end
        end
    end

endmodule
