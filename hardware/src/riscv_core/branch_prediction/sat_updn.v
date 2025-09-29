/*
A saturating incrementer/decrementer.
Adds +/-1 to the input with saturation to prevent overflow.
*/

module sat_updn #(
    parameter WIDTH=2
) (
    input [WIDTH-1:0] in,
    input up,
    input dn,

    output reg [WIDTH-1:0] out
);

    // TODO: Your code
    always @(*) begin
		if (up) begin
			out = (in < ((2 ** WIDTH) - 1)) ? (in + 1) : in;
		end
		else if (dn) begin
			out = (in > 0) ? (in - 1) : in;
		end
		else begin
			out = in;
		end
	end

endmodule
