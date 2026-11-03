// Penghitung dan task pemeriksaan yang dipakai bersama oleh semua testbench.
// File ini di-include di dalam modul testbench.

integer tests  = 0;
integer errors = 0;

task check;
    input [8*56-1:0] name;
    input [31:0]     got;
    input [31:0]     expected;
    begin
        tests = tests + 1;
        if (got !== expected) begin
            errors = errors + 1;
            $display("  [FAIL] %0s: got %h, expected %h", name, got, expected);
        end else begin
            $display("  [PASS] %0s", name);
        end
    end
endtask

task section;
    input [8*56-1:0] name;
    begin
        $display("\n== %0s ==", name);
    end
endtask

task finish_tb;
    begin
        $display("\n----------------------------------------");
        if (errors == 0) $display("RESULT: PASS (%0d checks)", tests);
        else             $display("RESULT: FAIL (%0d of %0d checks failed)", errors, tests);
        $display("----------------------------------------");
        $finish;
    end
endtask
