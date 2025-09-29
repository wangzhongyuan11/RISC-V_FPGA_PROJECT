`timescale 1ns/1ns

module mmult_tb();
  reg clk, rst;
  parameter CPU_CLOCK_PERIOD = 20; // 20ns -> 50 MHz
  parameter CPU_CLOCK_FREQ   = 1_000_000_000 / CPU_CLOCK_PERIOD;

  // 时钟
  initial clk = 0;
  always #(CPU_CLOCK_PERIOD/2) clk = ~clk;

  // CPU 实例
  cpu #(
    .CPU_CLOCK_FREQ(CPU_CLOCK_FREQ)
  ) dut (
    .clk(clk),
    .rst(rst),
    .serial_in(1'b1),
    .serial_out(),
    .bp_enable(1'b0) // 启用分支预测
  );

  // 仿真初始化
  initial begin

    #5;
    // 把 mmult.hex 加载到 BIOS 存储器
    $readmemh("../../software/mmult/mmult.hex", dut.bios_mem.mem);

    `ifdef IVERILOG
      $dumpfile("mmult_tb.fst");
      $dumpvars(0, mmult_tb);
    `endif

    // 复位
    rst = 1;
    repeat (10) @(posedge clk);
    rst = 0;

    // ------------------------------------------------
    // 这里你要确保 mmult.hex 已经被 bios_mem/imem 加载
    // 否则需要在 tb 里加 $readmemh
    // ------------------------------------------------z

    // 等待足够长时间，让 mmult 跑完
    // 如果 mmult 程序里会写 x20 flag，可以换成 wait_for_reg_to_equal
    repeat (200000) @(posedge clk); // 先跑这么多 cycles，时间可以调大

    // 打印结果
    $display("--------------------------------------------------");
    $display("Cycle Counter       = %d", dut.cycle_counter);
    $display("Instruction Counter = %d", dut.instruction_counter);
    $display("CPI = %f",
             real'(dut.cycle_counter) / real'(dut.instruction_counter));
    $display("--------------------------------------------------");

    $finish;
  end

endmodule
