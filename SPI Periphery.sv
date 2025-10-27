//===========================================================
// SPI Peripheral Module
// Compatible with SPI_Controller (supports 6 peripherals)
//===========================================================
module SPI_Periphery #(
  parameter int PAUSE = 5,                       // Controller pause cycles between TX and RX
  parameter int LENGTH_SEND = 8,                 // Bits sent from peripheral -> controller
  parameter int LENGTH_RECEIVED = 8,             // Bits received from controller -> peripheral
  parameter int LENGTH_COUNT = 5                 // Counter width (enough for full SPI cycle)
)(
  input  logic                   SCK,            // Shared serial clock from controller
  input  logic                   COPI,           // Controller-Out Peripheral-In
  inout  wire                    CIPO,           // Peripheral-Out Controller-In (shared tri-state)
  input  logic                   CS,             // Active-low chip select
  input  logic [LENGTH_SEND-1:0] data_send,      // Parallel data to send to controller
  input  logic                   rst,            // Active-high asynchronous reset

  output logic [LENGTH_RECEIVED-1:0] COPI_register // Parallel data received from controller
);

  //===========================================================
  // Internal registers and control
  //===========================================================
  logic [LENGTH_SEND-1:0]       CIPO_shiftreg;    // Data to send (shifted out)
  logic [LENGTH_COUNT-1:0]      count_pos;        // Posedge counter (for sampling)
  logic [LENGTH_COUNT-1:0]      count_neg;        // Negedge counter (for shifting)
  logic                         CIPO_drive;       // Internal line driving signal

  //===========================================================
  // Posedge SCK domain: sample COPI from controller
  //===========================================================
  always_ff @(posedge SCK or posedge rst) begin
    if (rst) begin
      count_pos     <= '0;
      COPI_register <= '0;
    end else if (!CS) begin  // active only when chip is selected
      count_pos <= count_pos + 1;

      // During receive phase: shift in COPI bits
      // Peripheral samples COPI (controller's data output) on SCK rising edge
      if (count_pos < LENGTH_RECEIVED)
        COPI_register <= {COPI, COPI_register[LENGTH_RECEIVED-1:1]};
    end else begin
      count_pos <= '0; // reset counter when deselected
    end
  end

  //===========================================================
  // Negedge SCK domain: shift out peripheral data (CIPO)
  //===========================================================
  always_ff @(negedge SCK or posedge rst) begin
    if (rst) begin
      count_neg     <= '0;
      CIPO_shiftreg <= '0;
      CIPO_drive    <= 1'bz; // high-Z when reset
    end else if (!CS) begin  // active only when selected
      if (count_neg == 0)
        CIPO_shiftreg <= data_send;  // load data to transmit at start of frame

      // Send LSB first, shift right each negedge
      if (count_neg < LENGTH_SEND) begin
        CIPO_drive    <= CIPO_shiftreg[0];
        CIPO_shiftreg <= CIPO_shiftreg >> 1;
        count_neg     <= count_neg + 1;
      end
      else begin
        // After sending all bits, release line
        CIPO_drive <= 1'bz;
      end
    end else begin
      // When deselected, reset state and release line
      CIPO_drive <= 1'bz;
      count_neg  <= '0;
    end
  end

  //===========================================================
  // Tri-state CIPO line (shared among all peripherals)
  //===========================================================
  assign CIPO = (!CS) ? CIPO_drive : 1'bz;

endmodule
