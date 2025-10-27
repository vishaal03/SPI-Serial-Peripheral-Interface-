`timescale 1ns/100ps

module SPI_TB();

  //===========================================================
  // Parameters (match top-level SPI)
  //===========================================================
  parameter int PAUSE             = 5;
  parameter int LENGTH_SEND_C     = 8;   // controller -> peripheral width
  parameter int LENGTH_SEND_P     = 16;  // peripheral -> controller width
  parameter int LENGTH_RECEIVED_C = 16;  // controller receives 16 bits from peripheral
  parameter int LENGTH_RECEIVED_P = 8;   // peripheral receives 8 bits from controller (not used for checks)
  parameter int LENGTH_COUNT_C    = 6;   // wide enough for full frame counting
  parameter int LENGTH_COUNT_P    = 6;
  parameter int PERIPHERY_COUNT   = 6;   // *** six peripherals ***
  parameter int PERIPHERY_SELECT  = 3;

  // Derived (for waiting)
  localparam int TX_CYCLES  = LENGTH_SEND_C;
  localparam int PAUSE_CYCLES = PAUSE;
  localparam int RX_CYCLES  = LENGTH_RECEIVED_C;
  localparam int EXTRA_CYCLES = 2;
  localparam int TOTAL_CYCLES = TX_CYCLES + PAUSE_CYCLES + RX_CYCLES + EXTRA_CYCLES;

  //===========================================================
  // Signals
  //===========================================================
  logic                         clk;
  logic                         rst;            // active-high reset (modules use posedge rst)
  logic                         start_comm;
  logic [PERIPHERY_SELECT-1:0]  CS_in;
  logic [LENGTH_SEND_C-1:0]     data_send_c;
  logic [LENGTH_SEND_P-1:0]     data_send_p;

  // helper for checking peripheral COPI registers
  logic [LENGTH_SEND_C-1:0]     COPI_register_compare;

  //===========================================================
  // DUT instantiation (top-level SPI)
  //===========================================================
  SPI #(
    .PAUSE(PAUSE),
    .LENGTH_SEND_C(LENGTH_SEND_C),
    .LENGTH_SEND_P(LENGTH_SEND_P),
    .LENGTH_RECEIVED_C(LENGTH_RECEIVED_C),
    .LENGTH_RECEIVED_P(LENGTH_RECEIVED_P),
    .LENGTH_COUNT_C(LENGTH_COUNT_C),
    .LENGTH_COUNT_P(LENGTH_COUNT_P),
    .PERIPHERY_COUNT(PERIPHERY_COUNT),
    .PERIPHERY_SELECT(PERIPHERY_SELECT)
  ) dut (
    .rst(rst),
    .clk(clk),
    .data_send_c(data_send_c),
    .data_send_p(data_send_p),
    .start_comm(start_comm),
    .CS_in(CS_in)
  );

  //===========================================================
  // Clock generation (10 ns period)
  //===========================================================
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  //===========================================================
  // Map chosen peripheral's COPI_register into a compare bus
  // (so we can check which peripheral captured the controller's COPI)
  //===========================================================
  always_comb begin
    case (CS_in)
      3'd0: COPI_register_compare = dut.COPI_register_0;
      3'd1: COPI_register_compare = dut.COPI_register_1;
      3'd2: COPI_register_compare = dut.COPI_register_2;
      3'd3: COPI_register_compare = dut.COPI_register_3;
      3'd4: COPI_register_compare = dut.COPI_register_4;
      3'd5: COPI_register_compare = dut.COPI_register_5;
      default: COPI_register_compare = '0;
    endcase
  end

  //===========================================================
  // Test sequence
  //===========================================================
  initial begin
    // initialize
    rst         = 1'b1;      // assert reset (active-high)
    start_comm  = 1'b0;
    CS_in       = '0;
    data_send_c = '0;
    data_send_p = '0;

    // hold reset for a few clock cycles
    repeat (5) @(posedge clk);
    rst = 1'b0;              // deassert reset -> design runs

    $display("\n=== SPI Testbench START ===\n");

    // ----------------------------
    // Test 1: 10 transactions with peripheral 0
    // ----------------------------
    CS_in = 3'd0;
    for (int k = 0; k < 10; k++) begin
      // produce random data
      data_send_c = $urandom_range(0, 2**LENGTH_SEND_C - 1);
      data_send_p = $urandom_range(0, 2**LENGTH_SEND_P - 1);

      // pulse start_comm for one posedge cycle (controller samples on posedge)
      @(negedge clk);
        start_comm = 1'b1;
      @(negedge clk);
        start_comm = 1'b0;

      $display("[%0t] Test1 iter %0d: start -> CS=%0d, controller sends 0x%0h, peripheral should send 0x%0h",
               $time, k, CS_in, data_send_c, data_send_p);

      // wait for the whole transaction to complete (TOTAL_CYCLES posedges)
      repeat (TOTAL_CYCLES + 2) @(posedge clk);

      // check controller received peripheral data (CIPO_register)
      if (dut.CIPO_register === data_send_p) begin
        $display("[%0t] PASS: controller received expected data 0x%0h", $time, dut.CIPO_register);
      end else begin
        $error("[%0t] FAIL: controller expected 0x%0h but got 0x%0h", $time, data_send_p, dut.CIPO_register);
        $finish;
      end

      // check peripheral captured controller COPI (peripheral 0)
      if (dut.COPI_register_0 === data_send_c) begin
        $display("[%0t] PASS: peripheral 0 captured controller data 0x%0h", $time, dut.COPI_register_0);
      end else begin
        $error("[%0t] FAIL: peripheral 0 expected to capture 0x%0h but got 0x%0h",
               $time, data_send_c, dut.COPI_register_0);
        $finish;
      end

      $display("-----------------------------------------------------------");
    end
    $display("Test 1 completed successfully.\n");

    // ----------------------------
    // Test 2: retrigger start while busy (simulate jitter)
    // ----------------------------
    CS_in = 3'd0;
    for (int k = 0; k < 10; k++) begin
      data_send_c = $urandom_range(0, 2**LENGTH_SEND_C - 1);
      data_send_p = $urandom_range(0, 2**LENGTH_SEND_P - 1);

      // initial start
      @(negedge clk);
        start_comm = 1'b1;
      @(negedge clk);
        start_comm = 1'b0;

      // wait a random number of cycles shorter than TOTAL_CYCLES, then try to retrigger
      int wait_rand = $urandom_range(0, TOTAL_CYCLES-1);
      repeat (wait_rand) @(posedge clk);

      // attempt re-trigger while busy
      @(negedge clk);
        start_comm = 1'b1;
      @(negedge clk);
        start_comm = 1'b0;

      // wait for remaining cycles to complete
      repeat (TOTAL_CYCLES + 2 - wait_rand) @(posedge clk);

      // verify
      if (dut.CIPO_register === data_send_p) begin
        $display("[%0t] PASS: controller received expected data 0x%0h (retrigger test)", $time, dut.CIPO_register);
      end else begin
        $error("[%0t] FAIL: controller expected 0x%0h but got 0x%0h (retrigger test)", $time, data_send_p, dut.CIPO_register);
        $finish;
      end

      if (dut.COPI_register_0 === data_send_c) begin
        $display("[%0t] PASS: peripheral 0 captured controller data 0x%0h (retrigger test)", $time, dut.COPI_register_0);
      end else begin
        $error("[%0t] FAIL: peripheral 0 expected 0x%0h but got 0x%0h (retrigger test)", $time, data_send_c, dut.COPI_register_0);
        $finish;
      end

      $display("-----------------------------------------------------------");
    end
    $display("Test 2 completed successfully.\n");

    // ----------------------------
    // Test 3: Random peripheral selection (0..5)
    // ----------------------------
    for (int k = 0; k < 20; k++) begin
      data_send_c = $urandom_range(0, 2**LENGTH_SEND_C - 1);
      data_send_p = $urandom_range(0, 2**LENGTH_SEND_P - 1);
      CS_in = $urandom_range(0, PERIPHERY_COUNT - 1);

      // start
      @(negedge clk);
        start_comm = 1'b1;
      @(negedge clk);
        start_comm = 1'b0;

      $display("[%0t] Test3 iter %0d: start -> CS=%0d, controller sends 0x%0h, peripheral should send 0x%0h",
               $time, k, CS_in, data_send_c, data_send_p);

      // wait full transaction
      repeat (TOTAL_CYCLES + 2) @(posedge clk);

      // check controller received expected peripheral data
      if (dut.CIPO_register === data_send_p) begin
        $display("[%0t] PASS: controller received expected data 0x%0h from peripheral %0d", $time, dut.CIPO_register, CS_in);
      end else begin
        $error("[%0t] FAIL: controller expected 0x%0h but got 0x%0h from peripheral %0d", $time, data_send_p, dut.CIPO_register, CS_in);
        $finish;
      end

      // check the selected peripheral captured controller COPI
      if (COPI_register_compare === data_send_c) begin
        $display("[%0t] PASS: peripheral %0d captured controller data 0x%0h", $time, CS_in, COPI_register_compare);
      end else begin
        $error("[%0t] FAIL: peripheral %0d expected 0x%0h but captured 0x%0h",
               $time, CS_in, data_send_c, COPI_register_compare);
        $finish;
      end

      $display("-----------------------------------------------------------");
    end
    $display("Test 3 completed successfully.\n");

    $display("=== All tests PASSED ===");
    #100;
    $finish;
  end

endmodule
