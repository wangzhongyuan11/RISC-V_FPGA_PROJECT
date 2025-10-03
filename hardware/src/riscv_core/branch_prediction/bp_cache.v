/*
A 2-way set associative cache module for storing branch prediction data.
Inputs: 2 asynchronous read ports and 1 synchronous write port.
Outputs: data and cache hit (for each read port)
*/
module bp_cache #(
    parameter AWIDTH=32,  // Address bit width
    parameter DWIDTH=32,  // Data bit width
    parameter LINES=128   // Number of cache lines (total)
) (
    input clk,
    input reset,
    // IO for 1st read port
    input [AWIDTH-1:0] ra0,
    output [DWIDTH-1:0] dout0,
    output hit0,
    // IO for 2nd read port
    input [AWIDTH-1:0] ra1,
    output [DWIDTH-1:0] dout1,
    output hit1,
    // IO for write port
    input [AWIDTH-1:0] wa,
    input [DWIDTH-1:0] din,
    input we
);
    // 2-way set associative: 128 lines total = 64 sets × 2 ways
    localparam WAYS = 2;
    localparam SETS = LINES / WAYS;  // 64 sets
    localparam set_index_bits = $clog2(SETS);  // 6 bits for set index
    localparam size_tag = AWIDTH - set_index_bits;  // Tag bits
    localparam size_data = DWIDTH;
    
    // Cache storage arrays - now we have 2 ways
    reg [size_tag-1:0] tag_way0 [0:SETS-1];
    reg [size_tag-1:0] tag_way1 [0:SETS-1];
    reg [SETS-1:0] valid_way0;
    reg [SETS-1:0] valid_way1;
    reg [size_data-1:0] data_way0 [0:SETS-1];
    reg [size_data-1:0] data_way1 [0:SETS-1];
    
    // LRU bits for replacement policy (1 bit per set: 0=way0 was used recently, 1=way1 was used recently)
    reg [SETS-1:0] lru;
    
    // Extract set index and tag from addresses
    wire [set_index_bits-1:0] set_idx_ra0 = ra0[set_index_bits-1:0];
    wire [size_tag-1:0] tag_ra0 = ra0[AWIDTH-1:set_index_bits];
    
    wire [set_index_bits-1:0] set_idx_ra1 = ra1[set_index_bits-1:0];
    wire [size_tag-1:0] tag_ra1 = ra1[AWIDTH-1:set_index_bits];
    
    wire [set_index_bits-1:0] set_idx_wa = wa[set_index_bits-1:0];
    wire [size_tag-1:0] tag_wa = wa[AWIDTH-1:set_index_bits];
    
    // Check hits for read port 0
    wire hit0_way0 = valid_way0[set_idx_ra0] && (tag_way0[set_idx_ra0] == tag_ra0);
    wire hit0_way1 = valid_way1[set_idx_ra0] && (tag_way1[set_idx_ra0] == tag_ra0);
    assign hit0 = hit0_way0 || hit0_way1;
    
    // Check hits for read port 1
    wire hit1_way0 = valid_way0[set_idx_ra1] && (tag_way0[set_idx_ra1] == tag_ra1);
    wire hit1_way1 = valid_way1[set_idx_ra1] && (tag_way1[set_idx_ra1] == tag_ra1);
    assign hit1 = hit1_way0 || hit1_way1;
    
    // Output data selection for read port 0
    assign dout0 = hit0_way0 ? data_way0[set_idx_ra0] : 
                   hit0_way1 ? data_way1[set_idx_ra0] : 
                   {DWIDTH{1'b0}};
    
    // Output data selection for read port 1
    assign dout1 = hit1_way0 ? data_way0[set_idx_ra1] : 
                   hit1_way1 ? data_way1[set_idx_ra1] : 
                   {DWIDTH{1'b0}};
    
    // Check if write address hits in cache
    wire write_hit_way0 = valid_way0[set_idx_wa] && (tag_way0[set_idx_wa] == tag_wa);
    wire write_hit_way1 = valid_way1[set_idx_wa] && (tag_way1[set_idx_wa] == tag_wa);
    
    // Synchronous writes with LRU replacement
    always @(posedge clk) begin
        if (reset) begin
            valid_way0 <= 0;
            valid_way1 <= 0;
            lru <= 0;
        end
        else if (we) begin
            if (write_hit_way0) begin
                // Update existing entry in way 0
                data_way0[set_idx_wa] <= din;
                lru[set_idx_wa] <= 1'b1;  // Mark way0 as recently used (next evict way1)
            end
            else if (write_hit_way1) begin
                // Update existing entry in way 1
                data_way1[set_idx_wa] <= din;
                lru[set_idx_wa] <= 1'b0;  // Mark way1 as recently used (next evict way0)
            end
            else begin
                // Miss - need to allocate new entry using LRU
                if (!lru[set_idx_wa]) begin
                    // LRU points to way0, so replace way0
                    tag_way0[set_idx_wa] <= tag_wa;
                    valid_way0[set_idx_wa] <= 1'b1;
                    data_way0[set_idx_wa] <= din;
                    lru[set_idx_wa] <= 1'b1;  // Mark way0 as recently used
                end
                else begin
                    // LRU points to way1, so replace way1
                    tag_way1[set_idx_wa] <= tag_wa;
                    valid_way1[set_idx_wa] <= 1'b1;
                    data_way1[set_idx_wa] <= din;
                    lru[set_idx_wa] <= 1'b0;  // Mark way1 as recently used
                end
            end
        end
        else begin
            // Update LRU on reads (optional - helps with better replacement decisions)
            // Update LRU for read port 0
            if (hit0_way0) begin
                lru[set_idx_ra0] <= 1'b1;  // Way0 was used
            end
            else if (hit0_way1) begin
                lru[set_idx_ra0] <= 1'b0;  // Way1 was used
            end
            
            // Update LRU for read port 1 (only if different from port 0 to avoid conflicts)
            if (set_idx_ra1 != set_idx_ra0) begin
                if (hit1_way0) begin
                    lru[set_idx_ra1] <= 1'b1;  // Way0 was used
                end
                else if (hit1_way1) begin
                    lru[set_idx_ra1] <= 1'b0;  // Way1 was used
                end
            end
        end
    end
    
endmodule