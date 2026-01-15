//==============================================================================
// Neural Network Reference Model - Άσκηση 4
// Συνάρτηση αναφοράς για σύγκριση με το νευρωνικό κύκλωμα
//==============================================================================

// Αυτή η συνάρτηση βρίσκεται ενσωματωμένη στο tb_nn.v
// Ορίζεται ως function nn_model που υπολογίζει το αναμενόμενο αποτέλεσμα

// Σταθερές ROM (ίδιες με το nn.v)
// ROM_SHIFT_BIAS_1 = 2
// ROM_SHIFT_BIAS_2 = 2  
// ROM_WEIGHT_1 = 3
// ROM_BIAS_1 = 1
// ROM_WEIGHT_2 = 2
// ROM_BIAS_2 = 2
// ROM_WEIGHT_3 = 2
// ROM_WEIGHT_4 = 1
// ROM_BIAS_3 = 3
// ROM_SHIFT_BIAS_3 = 1

// Υπολογισμός:
// inter_1 = input_1 >>> 2
// inter_2 = input_2 >>> 2
// inter_3 = inter_1 * 3 + 1
// inter_4 = inter_2 * 2 + 2
// inter_5 = inter_3 * 2 + inter_4 * 1 + 3
// output = inter_5 <<< 1

// Παράδειγμα:
// input_1 = 100, input_2 = 80
// inter_1 = 100 >>> 2 = 25
// inter_2 = 80 >>> 2 = 20
// inter_3 = 25 * 3 + 1 = 76
// inter_4 = 20 * 2 + 2 = 42
// inter_5 = 76 * 2 + 42 * 1 + 3 = 152 + 42 + 3 = 197
// output = 197 <<< 1 = 394

module nn_model_reference;
    // Αυτό το module είναι μόνο για τεκμηρίωση
    // Η πραγματική υλοποίηση βρίσκεται στο tb_nn.v
endmodule
