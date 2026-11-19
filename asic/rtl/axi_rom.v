// DIBUAT OTOMATIS oleh tools/hex_to_rom_v.py dari nim_scroll_asic_words.hex.
// Jangan diedit; jalankan ulang skrip setelah firmware berubah.
//
// axi_rom versi ASIC: isi ROM sebagai logika kombinasional (402 dari
// 512 word terpakai, sisanya 0). Port sama dengan rtl/axi_rom.v; port
// tulis loader (ld_*) diabaikan karena ROM ASIC tidak bisa ditulis.
// Parameter ADDR_BITS dan INIT_FILE hanya untuk kecocokan port.

module axi_rom #(
    parameter ADDR_BITS = 9,
    parameter INIT_FILE = ""
) (
    input         clk,
    input         rst_n,

    input         axi_arvalid,
    output        axi_arready,
    input  [31:0] axi_araddr,
    output        axi_rvalid,
    input         axi_rready,
    output [31:0] axi_rdata,

    input         ld_we,
    input  [31:0] ld_addr,
    input  [31:0] ld_data
);

    // Isi ROM sebagai logika kombinasional. Sengaja memakai always @(*)
    // biasa, bukan function yang dipanggil di blok clock: Yosys (LibreLane)
    // tidak membangun function seperti itu dengan benar.
    wire [8:0] rom_addr = axi_araddr[10:2];
    reg  [31:0] rom_q;
    always @(*) begin
        case (rom_addr)
            9'd0: rom_q = 32'h10000117;
            9'd1: rom_q = 32'h10010113;
            9'd2: rom_q = 32'h00000297;
            9'd3: rom_q = 32'h64028293;
            9'd4: rom_q = 32'h10000317;
            9'd5: rom_q = 32'hff030313;
            9'd6: rom_q = 32'h10000397;
            9'd7: rom_q = 32'hfe838393;
            9'd8: rom_q = 32'h00737c63;
            9'd9: rom_q = 32'h0002ae03;
            9'd10: rom_q = 32'h01c32023;
            9'd11: rom_q = 32'h00428293;
            9'd12: rom_q = 32'h00430313;
            9'd13: rom_q = 32'hfedff06f;
            9'd14: rom_q = 32'h10000317;
            9'd15: rom_q = 32'hfc830313;
            9'd16: rom_q = 32'h10000397;
            9'd17: rom_q = 32'hfc838393;
            9'd18: rom_q = 32'h00737863;
            9'd19: rom_q = 32'h00032023;
            9'd20: rom_q = 32'h00430313;
            9'd21: rom_q = 32'hff5ff06f;
            9'd22: rom_q = 32'h00000097;
            9'd23: rom_q = 32'h348080e7;
            9'd24: rom_q = 32'h0000006f;
            9'd25: rom_q = 32'h00151513;
            9'd26: rom_q = 32'h00657513;
            9'd27: rom_q = 32'h0185f593;
            9'd28: rom_q = 32'h100007b7;
            9'd29: rom_q = 32'h00b56533;
            9'd30: rom_q = 32'h00078793;
            9'd31: rom_q = 32'h00156513;
            9'd32: rom_q = 32'h00a7a023;
            9'd33: rom_q = 32'h00020737;
            9'd34: rom_q = 32'h00072423;
            9'd35: rom_q = 32'h00c72223;
            9'd36: rom_q = 32'h0007a783;
            9'd37: rom_q = 32'h00f72023;
            9'd38: rom_q = 32'h00008067;
            9'd39: rom_q = 32'h000207b7;
            9'd40: rom_q = 32'h00a7a423;
            9'd41: rom_q = 32'h00008067;
            9'd42: rom_q = 32'h000207b7;
            9'd43: rom_q = 32'h00a7a623;
            9'd44: rom_q = 32'h00020737;
            9'd45: rom_q = 32'h01072783;
            9'd46: rom_q = 32'h0017f793;
            9'd47: rom_q = 32'hfe079ce3;
            9'd48: rom_q = 32'h00c72503;
            9'd49: rom_q = 32'h0ff57513;
            9'd50: rom_q = 32'h00008067;
            9'd51: rom_q = 32'h100007b7;
            9'd52: rom_q = 32'h0007a683;
            9'd53: rom_q = 32'h00078793;
            9'd54: rom_q = 32'hfdf6f713;
            9'd55: rom_q = 32'h00050463;
            9'd56: rom_q = 32'h0206e713;
            9'd57: rom_q = 32'h00e7a023;
            9'd58: rom_q = 32'h000207b7;
            9'd59: rom_q = 32'h00e7a023;
            9'd60: rom_q = 32'h00008067;
            9'd61: rom_q = 32'h000207b7;
            9'd62: rom_q = 32'h0147a503;
            9'd63: rom_q = 32'hacafb7b7;
            9'd64: rom_q = 32'h6cf78793;
            9'd65: rom_q = 32'h00f50533;
            9'd66: rom_q = 32'h00153513;
            9'd67: rom_q = 32'h00008067;
            9'd68: rom_q = 32'hff010113;
            9'd69: rom_q = 32'h100007b7;
            9'd70: rom_q = 32'h00812423;
            9'd71: rom_q = 32'h00050413;
            9'd72: rom_q = 32'h0047a503;
            9'd73: rom_q = 32'h00112623;
            9'd74: rom_q = 32'h00000097;
            9'd75: rom_q = 32'hf74080e7;
            9'd76: rom_q = 32'h00040513;
            9'd77: rom_q = 32'h00000097;
            9'd78: rom_q = 32'hf74080e7;
            9'd79: rom_q = 32'h00812403;
            9'd80: rom_q = 32'h00c12083;
            9'd81: rom_q = 32'h00000513;
            9'd82: rom_q = 32'h01010113;
            9'd83: rom_q = 32'h00000317;
            9'd84: rom_q = 32'hf5030067;
            9'd85: rom_q = 32'hff010113;
            9'd86: rom_q = 32'h00812423;
            9'd87: rom_q = 32'h01212023;
            9'd88: rom_q = 32'h00058413;
            9'd89: rom_q = 32'h00050913;
            9'd90: rom_q = 32'h01800593;
            9'd91: rom_q = 32'h00300513;
            9'd92: rom_q = 32'h00112623;
            9'd93: rom_q = 32'h00912223;
            9'd94: rom_q = 32'h00000097;
            9'd95: rom_q = 32'heec080e7;
            9'd96: rom_q = 32'h00100793;
            9'd97: rom_q = 32'h100004b7;
            9'd98: rom_q = 32'h01279533;
            9'd99: rom_q = 32'h00448493;
            9'd100: rom_q = 32'h00a4a023;
            9'd101: rom_q = 32'h04000513;
            9'd102: rom_q = 32'h00000097;
            9'd103: rom_q = 32'hf78080e7;
            9'd104: rom_q = 32'h0004a503;
            9'd105: rom_q = 32'h01000493;
            9'd106: rom_q = 32'h00000097;
            9'd107: rom_q = 32'hef4080e7;
            9'd108: rom_q = 32'h0c000513;
            9'd109: rom_q = 32'h00000097;
            9'd110: rom_q = 32'hef4080e7;
            9'd111: rom_q = 32'h00000513;
            9'd112: rom_q = 32'hfff48493;
            9'd113: rom_q = 32'h00000097;
            9'd114: rom_q = 32'hee4080e7;
            9'd115: rom_q = 32'hfe0498e3;
            9'd116: rom_q = 32'h00000513;
            9'd117: rom_q = 32'h00000097;
            9'd118: rom_q = 32'hec8080e7;
            9'd119: rom_q = 32'h00747513;
            9'd120: rom_q = 32'h00812403;
            9'd121: rom_q = 32'h00c12083;
            9'd122: rom_q = 32'h00412483;
            9'd123: rom_q = 32'h00012903;
            9'd124: rom_q = 32'h08856513;
            9'd125: rom_q = 32'h01010113;
            9'd126: rom_q = 32'h00000317;
            9'd127: rom_q = 32'hf1830067;
            9'd128: rom_q = 32'hff010113;
            9'd129: rom_q = 32'h01212023;
            9'd130: rom_q = 32'h00050913;
            9'd131: rom_q = 32'h04000513;
            9'd132: rom_q = 32'h00112623;
            9'd133: rom_q = 32'h00812423;
            9'd134: rom_q = 32'h00912223;
            9'd135: rom_q = 32'h00058413;
            9'd136: rom_q = 32'h00060493;
            9'd137: rom_q = 32'h00000097;
            9'd138: rom_q = 32'heec080e7;
            9'd139: rom_q = 32'h100007b7;
            9'd140: rom_q = 32'h0047a503;
            9'd141: rom_q = 32'h009404b3;
            9'd142: rom_q = 32'h00000097;
            9'd143: rom_q = 32'he64080e7;
            9'd144: rom_q = 32'h00f97513;
            9'd145: rom_q = 32'h0c056513;
            9'd146: rom_q = 32'h00000097;
            9'd147: rom_q = 32'he60080e7;
            9'd148: rom_q = 32'h02941263;
            9'd149: rom_q = 32'h00812403;
            9'd150: rom_q = 32'h00c12083;
            9'd151: rom_q = 32'h00412483;
            9'd152: rom_q = 32'h00012903;
            9'd153: rom_q = 32'h00000513;
            9'd154: rom_q = 32'h01010113;
            9'd155: rom_q = 32'h00000317;
            9'd156: rom_q = 32'he3030067;
            9'd157: rom_q = 32'h00044503;
            9'd158: rom_q = 32'h00140413;
            9'd159: rom_q = 32'h00000097;
            9'd160: rom_q = 32'he2c080e7;
            9'd161: rom_q = 32'hfcdff06f;
            9'd162: rom_q = 32'h100007b7;
            9'd163: rom_q = 32'h0047a503;
            9'd164: rom_q = 32'hff010113;
            9'd165: rom_q = 32'h00112623;
            9'd166: rom_q = 32'h00812423;
            9'd167: rom_q = 32'h00912223;
            9'd168: rom_q = 32'h01212023;
            9'd169: rom_q = 32'h00000097;
            9'd170: rom_q = 32'hdf8080e7;
            9'd171: rom_q = 32'h04200513;
            9'd172: rom_q = 32'h00000097;
            9'd173: rom_q = 32'hdf8080e7;
            9'd174: rom_q = 32'h00100513;
            9'd175: rom_q = 32'h00000097;
            9'd176: rom_q = 32'he10080e7;
            9'd177: rom_q = 32'h00000493;
            9'd178: rom_q = 32'h00000413;
            9'd179: rom_q = 32'h00400913;
            9'd180: rom_q = 32'h00000513;
            9'd181: rom_q = 32'h00000097;
            9'd182: rom_q = 32'hdd4080e7;
            9'd183: rom_q = 32'h01157513;
            9'd184: rom_q = 32'h00951533;
            9'd185: rom_q = 32'h00a46433;
            9'd186: rom_q = 32'h00148493;
            9'd187: rom_q = 32'h0ff47413;
            9'd188: rom_q = 32'hff2490e3;
            9'd189: rom_q = 32'h00000513;
            9'd190: rom_q = 32'h00000097;
            9'd191: rom_q = 32'hdd4080e7;
            9'd192: rom_q = 32'h00000513;
            9'd193: rom_q = 32'h00000097;
            9'd194: rom_q = 32'hd98080e7;
            9'd195: rom_q = 32'h00c12083;
            9'd196: rom_q = 32'h00040513;
            9'd197: rom_q = 32'h00812403;
            9'd198: rom_q = 32'h00412483;
            9'd199: rom_q = 32'h00012903;
            9'd200: rom_q = 32'h01010113;
            9'd201: rom_q = 32'h00008067;
            9'd202: rom_q = 32'hfe010113;
            9'd203: rom_q = 32'h00010713;
            9'd204: rom_q = 32'h000008b7;
            9'd205: rom_q = 32'h00800813;
            9'd206: rom_q = 32'h00058613;
            9'd207: rom_q = 32'h00112e23;
            9'd208: rom_q = 32'hff850793;
            9'd209: rom_q = 32'h00070593;
            9'd210: rom_q = 32'h01100313;
            9'd211: rom_q = 32'h63488893;
            9'd212: rom_q = 32'h40a80833;
            9'd213: rom_q = 32'h00000693;
            9'd214: rom_q = 32'h00f36663;
            9'd215: rom_q = 32'h00f886b3;
            9'd216: rom_q = 32'h0006c683;
            9'd217: rom_q = 32'h00d70023;
            9'd218: rom_q = 32'h00f806b3;
            9'd219: rom_q = 32'h40c686b3;
            9'd220: rom_q = 32'h0016b693;
            9'd221: rom_q = 32'h00d700a3;
            9'd222: rom_q = 32'h00178793;
            9'd223: rom_q = 32'h00270713;
            9'd224: rom_q = 32'hfcf51ae3;
            9'd225: rom_q = 32'h01000613;
            9'd226: rom_q = 32'h00000513;
            9'd227: rom_q = 32'h00000097;
            9'd228: rom_q = 32'he74080e7;
            9'd229: rom_q = 32'h01c12083;
            9'd230: rom_q = 32'h02010113;
            9'd231: rom_q = 32'h00008067;
            9'd232: rom_q = 32'h00021737;
            9'd233: rom_q = 32'h00c72683;
            9'd234: rom_q = 32'hfd010113;
            9'd235: rom_q = 32'h554157b7;
            9'd236: rom_q = 32'h02112623;
            9'd237: rom_q = 32'h02812423;
            9'd238: rom_q = 32'h02912223;
            9'd239: rom_q = 32'h03212023;
            9'd240: rom_q = 32'h01312e23;
            9'd241: rom_q = 32'h01412c23;
            9'd242: rom_q = 32'h01512a23;
            9'd243: rom_q = 32'h01612823;
            9'd244: rom_q = 32'h01712623;
            9'd245: rom_q = 32'h01812423;
            9'd246: rom_q = 32'h01912223;
            9'd247: rom_q = 32'h23178793;
            9'd248: rom_q = 32'h04f69463;
            9'd249: rom_q = 32'h00872783;
            9'd250: rom_q = 32'h01079493;
            9'd251: rom_q = 32'h0104d493;
            9'd252: rom_q = 32'h00249793;
            9'd253: rom_q = 32'h009787b3;
            9'd254: rom_q = 32'h00479493;
            9'd255: rom_q = 32'h40f484b3;
            9'd256: rom_q = 32'h00749493;
            9'd257: rom_q = 32'hc0002a73;
            9'd258: rom_q = 32'h00000097;
            9'd259: rom_q = 32'hcec080e7;
            9'd260: rom_q = 32'h02051263;
            9'd261: rom_q = 32'h0000b7b7;
            9'd262: rom_q = 32'h00030737;
            9'd263: rom_q = 32'haaa78793;
            9'd264: rom_q = 32'h00f72023;
            9'd265: rom_q = 32'hffdff06f;
            9'd266: rom_q = 32'h000b74b7;
            9'd267: rom_q = 32'h1b048493;
            9'd268: rom_q = 32'hfd5ff06f;
            9'd269: rom_q = 32'h000f45b7;
            9'd270: rom_q = 32'h24058593;
            9'd271: rom_q = 32'h00048513;
            9'd272: rom_q = 32'h00000097;
            9'd273: rom_q = 32'h148080e7;
            9'd274: rom_q = 32'h00050613;
            9'd275: rom_q = 32'h00700593;
            9'd276: rom_q = 32'h00000513;
            9'd277: rom_q = 32'h00000097;
            9'd278: rom_q = 32'hd00080e7;
            9'd279: rom_q = 32'h00000593;
            9'd280: rom_q = 32'h00000513;
            9'd281: rom_q = 32'h00000097;
            9'd282: rom_q = 32'hec4080e7;
            9'd283: rom_q = 32'h000307b7;
            9'd284: rom_q = 32'h0007a023;
            9'd285: rom_q = 32'h00000913;
            9'd286: rom_q = 32'h00100c13;
            9'd287: rom_q = 32'h00000413;
            9'd288: rom_q = 32'h00000993;
            9'd289: rom_q = 32'h00030b37;
            9'd290: rom_q = 32'h00100b93;
            9'd291: rom_q = 32'h01a00a93;
            9'd292: rom_q = 32'h00000097;
            9'd293: rom_q = 32'hdf8080e7;
            9'd294: rom_q = 32'h00757c93;
            9'd295: rom_q = 32'hfff94793;
            9'd296: rom_q = 32'h00fcf7b3;
            9'd297: rom_q = 32'h00000593;
            9'd298: rom_q = 32'h02078463;
            9'd299: rom_q = 32'h0017f693;
            9'd300: rom_q = 32'h00000713;
            9'd301: rom_q = 32'h00069863;
            9'd302: rom_q = 32'h0027f793;
            9'd303: rom_q = 32'h0017b713;
            9'd304: rom_q = 32'h00170713;
            9'd305: rom_q = 32'h40e989b3;
            9'd306: rom_q = 32'h013035b3;
            9'd307: rom_q = 32'h00070993;
            9'd308: rom_q = 32'hc00027f3;
            9'd309: rom_q = 32'h414787b3;
            9'd310: rom_q = 32'h009a0933;
            9'd311: rom_q = 32'h0697e263;
            9'd312: rom_q = 32'h02099e63;
            9'd313: rom_q = 32'h020c0663;
            9'd314: rom_q = 32'h07540463;
            9'd315: rom_q = 32'h00140413;
            9'd316: rom_q = 32'h00098593;
            9'd317: rom_q = 32'h00040513;
            9'd318: rom_q = 32'h00000097;
            9'd319: rom_q = 32'he30080e7;
            9'd320: rom_q = 32'h00d41793;
            9'd321: rom_q = 32'h00fb2023;
            9'd322: rom_q = 32'h00090a13;
            9'd323: rom_q = 32'h03c0006f;
            9'd324: rom_q = 32'h04040663;
            9'd325: rom_q = 32'hfff40413;
            9'd326: rom_q = 32'hfd9ff06f;
            9'd327: rom_q = 32'h01799a63;
            9'd328: rom_q = 32'h05540463;
            9'd329: rom_q = 32'h00140413;
            9'd330: rom_q = 32'h00100c13;
            9'd331: rom_q = 32'hfc5ff06f;
            9'd332: rom_q = 32'h04040263;
            9'd333: rom_q = 32'hfff40413;
            9'd334: rom_q = 32'h00000c13;
            9'd335: rom_q = 32'hfb5ff06f;
            9'd336: rom_q = 32'h000a0913;
            9'd337: rom_q = 32'hfa0596e3;
            9'd338: rom_q = 32'h000c8913;
            9'd339: rom_q = 32'hf45ff06f;
            9'd340: rom_q = 32'h00000c13;
            9'd341: rom_q = 32'h01900413;
            9'd342: rom_q = 32'hf99ff06f;
            9'd343: rom_q = 32'h00100c13;
            9'd344: rom_q = 32'h00100413;
            9'd345: rom_q = 32'hf8dff06f;
            9'd346: rom_q = 32'h00100c13;
            9'd347: rom_q = 32'h00000413;
            9'd348: rom_q = 32'hf81ff06f;
            9'd349: rom_q = 32'h00000c13;
            9'd350: rom_q = 32'h01a00413;
            9'd351: rom_q = 32'hf75ff06f;
            9'd352: rom_q = 32'h06054063;
            9'd353: rom_q = 32'h0605c663;
            9'd354: rom_q = 32'h00058613;
            9'd355: rom_q = 32'h00050593;
            9'd356: rom_q = 32'hfff00513;
            9'd357: rom_q = 32'h02060c63;
            9'd358: rom_q = 32'h00100693;
            9'd359: rom_q = 32'h00b67a63;
            9'd360: rom_q = 32'h00c05863;
            9'd361: rom_q = 32'h00161613;
            9'd362: rom_q = 32'h00169693;
            9'd363: rom_q = 32'hfeb66ae3;
            9'd364: rom_q = 32'h00000513;
            9'd365: rom_q = 32'h00c5e663;
            9'd366: rom_q = 32'h40c585b3;
            9'd367: rom_q = 32'h00d56533;
            9'd368: rom_q = 32'h0016d693;
            9'd369: rom_q = 32'h00165613;
            9'd370: rom_q = 32'hfe0696e3;
            9'd371: rom_q = 32'h00008067;
            9'd372: rom_q = 32'h00008293;
            9'd373: rom_q = 32'hfb5ff0ef;
            9'd374: rom_q = 32'h00058513;
            9'd375: rom_q = 32'h00028067;
            9'd376: rom_q = 32'h40a00533;
            9'd377: rom_q = 32'h0005d863;
            9'd378: rom_q = 32'h40b005b3;
            9'd379: rom_q = 32'hf9dff06f;
            9'd380: rom_q = 32'h40b005b3;
            9'd381: rom_q = 32'h00008293;
            9'd382: rom_q = 32'hf91ff0ef;
            9'd383: rom_q = 32'h40a00533;
            9'd384: rom_q = 32'h00028067;
            9'd385: rom_q = 32'h00008293;
            9'd386: rom_q = 32'h0005ca63;
            9'd387: rom_q = 32'h00054c63;
            9'd388: rom_q = 32'hf79ff0ef;
            9'd389: rom_q = 32'h00058513;
            9'd390: rom_q = 32'h00028067;
            9'd391: rom_q = 32'h40b005b3;
            9'd392: rom_q = 32'hfe0558e3;
            9'd393: rom_q = 32'h40a00533;
            9'd394: rom_q = 32'hf61ff0ef;
            9'd395: rom_q = 32'h40b00533;
            9'd396: rom_q = 32'h00028067;
            9'd397: rom_q = 32'h6d405b5b;
            9'd398: rom_q = 32'h3f6f6d3f;
            9'd399: rom_q = 32'h7970407f;
            9'd400: rom_q = 32'h4f6d6d40;
            9'd401: rom_q = 32'h00006f6f;
            default: rom_q = 32'h00000000;
        endcase
    end

    reg [31:0] rdata_r;
    reg        read_en;

    always @(posedge clk) begin
        if (!rst_n) begin
            read_en <= 1'b0;
            rdata_r <= 32'h0;
        end else if (axi_arvalid && !read_en) begin
            rdata_r <= rom_q;
            read_en <= 1'b1;
        end else if (read_en && axi_rready) begin
            read_en <= 1'b0;
        end
    end

    assign axi_arready = ~read_en;
    assign axi_rvalid  = read_en;
    assign axi_rdata   = rdata_r;

    // Port yang tidak dipakai di ASIC
    wire unused_ok = &{1'b0, ld_we, ld_addr, ld_data, axi_araddr[31:11], axi_araddr[1:0]};

endmodule
