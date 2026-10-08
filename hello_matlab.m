%HELLO_MATLAB  Smoke test for the MATLAB MCP connection.
fprintf("hello from MATLAB %s\n", version("-release"));
x = 1:5;
fprintf("sum(1:5) = %d\n", sum(x));
