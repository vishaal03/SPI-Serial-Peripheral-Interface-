//====================================================
// SPI top-level module
// Controller with six peripheral units
//====================================================
module SPI #(
  parameter int PAUSE             = 5,   // Clock cycles between transmit and receive
  parameter int LENGTH_SEND_C     = 8,   // Controller -> Peripheral data width
  parameter int LENGTH_SEND_P     = 8,   // Peripheral -> Controller data width
  parameter int LENGTH_RECEIVED_C = 8,   // Controller received data width
  parameter int LENGTH_RECEIVED_P = 8,   // Peripheral received data width
  parameter int LENGTH_COUNT_C    = 5,   // Counter width (Controller)
  parameter int LENGTH_COUNT_P    = 5,   // Counter width (Peripheral)
  parameter int PERIPHERY_COUNT   = 6,   // Number of peripherals
  parameter int PERIPHERY_SELECT  = 3    // log2(6) ≈ 3 bits
)(
  input  logic rst,                           // Active-high reset
  input  logic clk,                           // System clock
  input  logic [LENGTH_SEND_C-1:0] data_send_c, // Controller parallel data
  input  logic [LENGTH_SEND_P-1:0] data_send_p, // Peripheral parallel data
  input  logic start_comm,                    // Start communication
  input  logic [PERIPHERY_SELECT-1:0] CS_in   // Peripheral select
);

  //=============================
  // Shared SPI Signals
  //=============================
  wire COPI;                                  // Controller Out - Peripheral In
  wire CIPO;                                  // Controller In - Peripheral Out
  wire SCK;                                   // Shared serial clock
  logic [PERIPHERY_COUNT-1:0] CS_out;         // Active-low chip selects

  //=============================
  // Internal registers
  //=============================
  logic [LENGTH_RECEIVED_C-1:0] CIPO_register;   // Data received by controller
  logic [LENGTH_SEND_C-1:0] COPI_register_0;     // Data received by peripheral 0
  logic [LENGTH_SEND_C-1:0] COPI_register_1;     // Data received by peripheral 1
  logic [LENGTH_SEND_C-1:0] COPI_register_2;     // Data received by peripheral 2
  logic [LENGTH_SEND_C-1:0] COPI_register_3;     // Data received by peripheral 3
  logic [LENGTH_SEND_C-1:0] COPI_register_4;     // Data received by peripheral 4
  logic [LENGTH_SEND_C-1:0] COPI_register_5;     // Data received by peripheral 5

  //==========================================================
  // Controller Instantiation
  //==========================================================
  SPI_Controller #(
    .PAUSE(PAUSE),
    .LENGTH_SEND(LENGTH_SEND_C),
    .LENGTH_RECEIVED(LENGTH_RECEIVED_C),
    .LENGTH_COUNT(LENGTH_COUNT_C),
    .PERIPHERY_COUNT(PERIPHERY_COUNT),
    .PERIPHERY_SELECT(PERIPHERY_SELECT)
  ) SPI_C_0 (
    .rst            (rst),
    .clk            (clk),
    .SCK            (SCK),
    .COPI           (COPI),
    .CIPO           (CIPO),
    .data_send      (data_send_c),
    .start_comm     (start_comm),
    .CS_in          (CS_in),
    .CS_out         (CS_out),
    .CIPO_register  (CIPO_register)
  );

  //==========================================================
  // Peripheral 0
  //==========================================================
  SPI_Periphery #(
    .LENGTH_SEND     (LENGTH_SEND_P),
    .LENGTH_RECEIVED (LENGTH_RECEIVED_P),
    .LENGTH_COUNT    (LENGTH_COUNT_P),
    .PAUSE           (PAUSE)
  ) SPI_P_0 (
    .SCK            (SCK),
    .COPI           (COPI),
    .CIPO           (CIPO),
    .CS             (CS_out[0]),
    .data_send      (data_send_p),
    .rst            (rst),
    .COPI_register  (COPI_register_0)
  );

  //==========================================================
  // Peripheral 1
  //==========================================================
  SPI_Periphery #(
    .LENGTH_SEND     (LENGTH_SEND_P),
    .LENGTH_RECEIVED (LENGTH_RECEIVED_P),
    .LENGTH_COUNT    (LENGTH_COUNT_P),
    .PAUSE           (PAUSE)
  ) SPI_P_1 (
    .SCK            (SCK),
    .COPI           (COPI),
    .CIPO           (CIPO),
    .CS             (CS_out[1]),
    .data_send      (data_send_p),
    .rst            (rst),
    .COPI_register  (COPI_register_1)
  );

  //==========================================================
  // Peripheral 2
  //==========================================================
  SPI_Periphery #(
    .LENGTH_SEND     (LENGTH_SEND_P),
    .LENGTH_RECEIVED (LENGTH_RECEIVED_P),
    .LENGTH_COUNT    (LENGTH_COUNT_P),
    .PAUSE           (PAUSE)
  ) SPI_P_2 (
    .SCK            (SCK),
    .COPI           (COPI),
    .CIPO           (CIPO),
    .CS             (CS_out[2]),
    .data_send      (data_send_p),
    .rst            (rst),
    .COPI_register  (COPI_register_2)
  );

  //==========================================================
  // Peripheral 3
  //==========================================================
  SPI_Periphery #(
    .LENGTH_SEND     (LENGTH_SEND_P),
    .LENGTH_RECEIVED (LENGTH_RECEIVED_P),
    .LENGTH_COUNT    (LENGTH_COUNT_P),
    .PAUSE           (PAUSE)
  ) SPI_P_3 (
    .SCK            (SCK),
    .COPI           (COPI),
    .CIPO           (CIPO),
    .CS             (CS_out[3]),
    .data_send      (data_send_p),
    .rst            (rst),
    .COPI_register  (COPI_register_3)
  );

  //==========================================================
  // Peripheral 4
  //==========================================================
  SPI_Periphery #(
    .LENGTH_SEND     (LENGTH_SEND_P),
    .LENGTH_RECEIVED (LENGTH_RECEIVED_P),
    .LENGTH_COUNT    (LENGTH_COUNT_P),
    .PAUSE           (PAUSE)
  ) SPI_P_4 (
    .SCK            (SCK),
    .COPI           (COPI),
    .CIPO           (CIPO),
    .CS             (CS_out[4]),
    .data_send      (data_send_p),
    .rst            (rst),
    .COPI_register  (COPI_register_4)
  );

  //==========================================================
  // Peripheral 5
  //==========================================================
  SPI_Periphery #(
    .LENGTH_SEND     (LENGTH_SEND_P),
    .LENGTH_RECEIVED (LENGTH_RECEIVED_P),
    .LENGTH_COUNT    (LENGTH_COUNT_P),
    .PAUSE           (PAUSE)
  ) SPI_P_5 (
    .SCK            (SCK),
    .COPI           (COPI),
    .CIPO           (CIPO),
    .CS             (CS_out[5]),
    .data_send      (data_send_p),
    .rst            (rst),
    .COPI_register  (COPI_register_5)
  );

endmodule
