`include "defines.v"

module ctrl(
    input  wire                 rst,
    input  wire                 stallreq_id,
    input  wire                 stallreq_exe,
    input  wire                 stallreq_mem,
    output reg  [5:0]           stall
);
    
    // 日志文件
    integer log_file;
    initial begin
        log_file = $fopen("stall_ctrl.txt", "w");
        if (log_file) $fwrite(log_file, "Simulation Start: CTRL Module Monitoring...\n");
    end

    always @(*) begin
        if (rst == `RST_ENABLE) begin
            stall = 6'b000000;
        end
        else if (stallreq_mem == `TRUE_V) begin
            stall = 6'b011111;
        end
        else if (stallreq_exe == `TRUE_V) begin
            stall = 6'b001111;
        end
        else if (stallreq_id == `TRUE_V) begin
            stall = 6'b000111; // ID暂停，EXE继续
        end
        else begin
            stall = 6'b000000;
        end
    end
    
    // 监控变化
    always @(stall) begin
        if (stall != 0) begin
            $fwrite(log_file, "[%t] CTRL OUTPUT: Stall=%b (req_id=%b, req_mem=%b)\n", $time, stall, stallreq_id, stallreq_mem);
            $fflush(log_file);
        end
    end
endmodule