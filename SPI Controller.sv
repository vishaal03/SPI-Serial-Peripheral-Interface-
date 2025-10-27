module SPI_Controller #(
  parameter int PAUSE = 5,                       // Number of controller clocks between TX and RX phases
  parameter int LENGTH_SEND = 8,                 // Bits to send (Controller -> Peripheral)
  parameter int LENGTH_RECEIVED = 8,             // Bits to receive (Peripheral -> Controller)
  parameter int PERIPHERY_COUNT = 6,             // Number of peripherals
  parameter int PERIPHERY_SELECT = 3             // Bits to select peripheral (log2(PERIPHERY_COUNT))
) (
  input  logic                          clk,        // Controller clock
  input  logic                          rst,        // Active-high asynchronous reset
  input  logic                          CIPO,       // Controller-In Peripheral-Out (serial in)
  input  logic [LENGTH_SEND-1:0]        data_send,  // Parallel data to send (must be valid when start asserted)
  input  logic                          start_comm, // Start pulse to initiate SPI transfer
  input  logic [PERIPHERY_SELECT-1:0]   CS_in,      // Peripheral select encoded (binary)

  output logic                          COPI,       // Controller-Out Peripheral-In (serial out)
  output logic                          SCK,        // Shared serial clock
  output logic [PERIPHERY_COUNT-1:0]    CS_out,     // Active-low chip selects (1=inactive, 0=active)
  output logic [LENGTH_RECEIVED-1:0]    CIPO_register, // Received parallel data
  output logic                          busy        // Busy indicator
);

  //===========================================================
  // Derived timing constants
  //===========================================================
  localparam int TX_CYCLES     = LENGTH_SEND;
  localparam int PAUSE_CYCLES  = PAUSE;
  localparam int RX_CYCLES     = LENGTH_RECEIVED;
  localparam int EXTRA_CYCLES  = 2;
  localparam int TOTAL_CYCLES  = TX_CYCLES + PAUSE_CYCLES + RX_CYCLES + EXTRA_CYCLES;

  // Counter width large enough to count all cycles
  localparam int COUNT_WIDTH = $clog2(TOTAL_CYCLES + 1);

  logic [COUNT_WIDTH-1:0] count_pos;     // Posedge domain counter
  logic [COUNT_WIDTH-1:0] count_neg;     // Negedge domain counter

  logic start_comm_delayed;
  logic start_pulse;
  logic [LENGTH_SEND-1:0] COPI_shiftreg;

  //===========================================================
  // Posedge clock domain: control, chip select, and receiving
  //===========================================================
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      start_comm_delayed <= 1'b0;
      start_pulse <= 1'b0;
      busy <= 1'b0;
      CIPO_register <= '0;
      count_pos <= TOTAL_CYCLES;
      CS_out <= {PERIPHERY_COUNT{1'b1}}; // all inactive
    end else begin
      // Generate single-cycle start pulse
      start_comm_delayed <= start_comm;
      start_pulse <= start_comm && !start_comm_delayed && !busy;

      if (start_pulse) begin
        count_pos <= '0;
        busy <= 1'b1;

        // Decode CS_in -> one-hot active-low CS_out
        CS_out <= {PERIPHERY_COUNT{1'b1}}; // default all inactive
        if (CS_in < PERIPHERY_COUNT)
          CS_out[CS_in] <= 1'b0;           // activate selected peripheral
      end
      else if (count_pos < TOTAL_CYCLES) begin
        count_pos <= count_pos + 1;
      end
      else begin
        busy <= 1'b0;
        CS_out <= {PERIPHERY_COUNT{1'b1}}; // deassert all
      end

      // Sample incoming CIPO during receive phase
      if ((count_pos >= (TX_CYCLES + PAUSE_CYCLES)) &&
          (count_pos <  (TX_CYCLES + PAUSE_CYCLES + RX_CYCLES))) begin
        CIPO_register <= {CIPO, CIPO_register[LENGTH_RECEIVED-1:1]};
      end
    end
  end

  //===========================================================
  // Negedge clock domain: transmit shift register (COPI)
  //===========================================================
  always_ff @(negedge clk or posedge rst) begin
    if (rst) begin
      COPI_shiftreg <= '0;
      COPI <= 1'b0;
      count_neg <= TOTAL_CYCLES;
    end else begin
      if (start_pulse) begin
        count_neg <= '0;
        COPI_shiftreg <= data_send;  // load data to send
      end
      else if (count_neg < TX_CYCLES) begin
        COPI <= COPI_shiftreg[0];
        COPI_shiftreg <= COPI_shiftreg >> 1;
        count_neg <= count_neg + 1;
      end
      else if (count_neg < TOTAL_CYCLES) begin
        count_neg <= count_neg + 1;
      end
    end
  end

  //===========================================================
  // Serial Clock (SCK) Generation
  //===========================================================
  always_comb begin
    if (count_pos < TX_CYCLES)
      SCK = clk;
    else if (count_pos < TX_CYCLES + PAUSE_CYCLES)
      SCK = 1'b1;
    else if (count_pos < TX_CYCLES + PAUSE_CYCLES + RX_CYCLES)
      SCK = clk;
    else
      SCK = 1'b1;
  end

endmodule
