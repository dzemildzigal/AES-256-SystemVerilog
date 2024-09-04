`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/04/2024 05:20:15 PM
// Design Name: 
// Module Name: SubBytesTestBench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SubBytesTestBench;
    // inputs are -> reg, outputs are -> wire
    reg clk;
    reg rst;
    reg [0:127] input_state;
    wire [0:127] output_state;
    wire valid_data;
    
    SubBytes sb(.clk(clk),  
                    .rst(rst), 
                    .input_state(input_state), 
                    .output_state(output_state), 
                    .valid_data(valid_data)
                    );
    initial begin
        clk = 0;
        rst = 0;
        @(posedge clk);
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        @(posedge clk);
        
        input_state = 128'h00000000000000000000000000000000;
        @(posedge clk);
        assert (output_state == 128'h63636363636363636363636363636363&& valid_data==1'b1);
        input_state = 128'h63636363636363636363636363636363;
        @(posedge clk);
        assert (output_state == 128'hfbfbfbfbfbfbfbfbfbfbfbfbfbfbfbfb&& valid_data==1'b1);
        input_state = 128'h99989898999898989998989899989898;
        @(posedge clk);
        assert (output_state == 128'hee464646ee464646ee464646ee464646&& valid_data==1'b1);
        input_state = 128'ha715155ea715155ea715155ea715155e;
        @(posedge clk);
        assert (output_state == 128'h5c5959585c5959585c5959585c595958&& valid_data==1'b1);
        input_state = 128'h3d31339b5f5250f83d31339b5f5250f8;
        @(posedge clk);
        assert (output_state == 128'h27c7c314cf00534127c7c314cf005341&& valid_data==1'b1);
        input_state = 128'hb1b5f44247cde467b1b5f44247cde467;
        @(posedge clk);
        assert (output_state == 128'hc8d5bf2ca0bd6985c8d5bf2ca0bd6985&& valid_data==1'b1);
        input_state = 128'h3ea2699124dd31725cc10af246be5211;
        @(posedge clk);
        assert (output_state == 128'hb23af98136c1c7404a7867895aae0082&& valid_data==1'b1);
        input_state = 128'h548aa1b524bb216bf82cb7335ff279b1;
        @(posedge clk);
        assert (output_state == 128'h207e32d536eafd7f4171a9c3cf89b6c8&& valid_data==1'b1);
        input_state = 128'h9a6d4f805c313969bea7ce61f4126cbd;
        @(posedge clk);
        assert (output_state == 128'hb83c84cd4ac712f9ae5c8befbfc9507a&& valid_data==1'b1);
        input_state = 128'he3e0d7b4870226dc2cf5c2f861a5272f;
        @(posedge clk);
        assert (output_state == 128'h11e10e8d1777f78671e62541ef06cc15&& valid_data==1'b1);
        input_state = 128'hef83ee19faf56e0535d8897cd3ba29a7;
        @(posedge clk);
        assert (output_state == 128'hdfec28d42de69f6b9661a71066f4a55c&& valid_data==1'b1);
        input_state = 128'h021d21888fb90f8422bc5c9a807ee6d6;
        @(posedge clk);
        assert (output_state == 128'h77a4fdc47356765f93654ab8cdf38ef6&& valid_data==1'b1);
        input_state = 128'h4f435cee40b33e66875b6b6536054c97;
        @(posedge clk);
        assert (output_state == 128'h841a4a28096db23317397f4d056b2988&& valid_data==1'b1);
        input_state = 128'h27ba9f2f2bb3647ec87d106a15916306;
        @(posedge clk);
        assert (output_state == 128'hccf4db15f16d43f3e8ffca025981fb6f&& valid_data==1'b1);
        input_state = 128'h000102030405060708090a0b0c0d0e0f;
        @(posedge clk);
        assert (output_state == 128'h637c777bf26b6fc53001672bfed7ab76&& valid_data==1'b1);
        input_state = 128'h7a7b4e5638782546a8c0477a3b813f43;
        @(posedge clk);
        assert (output_state == 128'hda212fb107bc3f5ac2baa0dae20c751a&& valid_data==1'b1);
        input_state = 128'h6f2bd1c2be305b27578eb059fc490810;
        @(posedge clk);
        assert (output_state == 128'ha8f13e25ae0439cc5b19e7cbb03b30ca&& valid_data==1'b1);
        input_state = 128'h7c0994427bad065013fef7aa8789cf50;
        @(posedge clk);
        assert (output_state == 128'h1001222c21956f537dbb68ac17a78a53&& valid_data==1'b1);
        input_state = 128'h114d7f9b3d14fa62df93be5fedf43273;
        @(posedge clk);
        assert (output_state == 128'h82e3d21427fa2daa9edcaecf55bf238f&& valid_data==1'b1);
        input_state = 128'h46ea44846950ce2cf0c490c80588f739;
        @(posedge clk);
        assert (output_state == 128'h5a871b5ff9538b718c1c60e86bc46812&& valid_data==1'b1);
        input_state = 128'hf5187d8633814dcd516aa15e4bc59bf1;
        @(posedge clk);
        assert (output_state == 128'he6adff44c30ce3bdd1023258b3a614a1&& valid_data==1'b1);
        input_state = 128'h6deb4c2399f850272d9ed0e47e93e409;
        @(posedge clk);
        assert (output_state == 128'h3ce92926ee4153ccd80b7069f3dc6901&& valid_data==1'b1);
        input_state = 128'hc1f30e28571e544f9c9e5ca126211b49;
        @(posedge clk);
        assert (output_state == 128'h780dab345b722084de0b4a32f7fdaf3b&& valid_data==1'b1);
        input_state = 128'h528c75a627219aa6a450b40f94b56e41;
        @(posedge clk);
        assert (output_state == 128'h00649d24ccfdb82449538d7622d59f83&& valid_data==1'b1);
        input_state = 128'h6e2195717340289f5c866a2bf42e1089;
        @(posedge clk);
        assert (output_state == 128'h9ffd2aa38f0934db4a4402f1bf31caa7&& valid_data==1'b1);
        input_state = 128'h6b369a1a47499320e1283d220f5cc4aa;
        @(posedge clk);
        assert (output_state == 128'h7f05b8a2a03bdcb7f8342793764a1cac&& valid_data==1'b1);
        input_state = 128'h1d8d1baf22bb51a9b21ba041f6e26274;
        @(posedge clk);
        assert (output_state == 128'ha45daf7993ead1d337afe0834298aa92&& valid_data==1'b1);
        input_state = 128'h4a985e5badb8b7b9df72af79fcebf5bd;
        @(posedge clk);
        assert (output_state == 128'hd6465839956ca9569e4079b6b0e9e67a&& valid_data==1'b1);
        input_state = 128'h00102030405060708090a0b0c0d0e0f0;
        @(posedge clk);
        assert (output_state == 128'h63cab7040953d051cd60e0e7ba70e18c&& valid_data==1'b1);
        input_state = 128'h4f63760643e0aa85efa7213201a4e705;
        @(posedge clk);
        assert (output_state == 128'h84fb386f1ae1ac97df5cfd237c49946b&& valid_data==1'b1);
        input_state = 128'h1859fbc28a1c00a078ed8aadc42f6109;
        @(posedge clk);
        assert (output_state == 128'hadcb0f257e9c63e0bc557e951c15ef01&& valid_data==1'b1);
        input_state = 128'h975c66c1cb9f3fa8a93a28df8ee10f63;
        @(posedge clk);
        assert (output_state == 128'h884a33781fdb75c2d380349e19f876fb&& valid_data==1'b1);
        input_state = 128'h1c05f271a417e04ff921c5c104701554;
        @(posedge clk);
        assert (output_state == 128'h9c6b89a349f0e18499fda678f2515920&& valid_data==1'b1);
        input_state = 128'hc357aae11b45b7b0a2c7bd28a8dc99fa;
        @(posedge clk);
        assert (output_state == 128'h2e5bacf8af6ea9e73ac67a34c286ee2d&& valid_data==1'b1);
        input_state = 128'h7f074143cb4e243ec10c815d8375d54c;
        @(posedge clk);
        assert (output_state == 128'hd2c5831a1f2f36b278fe0c4cec9d0329&& valid_data==1'b1);
        input_state = 128'hd653a4696ca0bc0f5acaab5db96c5e7d;
        @(posedge clk);
        assert (output_state == 128'hf6ed49f950e06576be74624c565058ff&& valid_data==1'b1);
        input_state = 128'h5aa858395fd28d7d05e1a38868f3b9c5;
        @(posedge clk);
        assert (output_state == 128'hbec26a12cfb55dff6bf80ac4450d56a6&& valid_data==1'b1);
        input_state = 128'h4a824851c57e7e47643de50c2af3e8c9;
        @(posedge clk);
        assert (output_state == 128'hd61352d1a6f3f3a04327d9fee50d9bdd&& valid_data==1'b1);
        input_state = 128'hc14907f6ca3b3aa070e9aa313b52b5ec;
        @(posedge clk);
        assert (output_state == 128'h783bc54274e280e0511eacc7e200d5ce&& valid_data==1'b1);
        input_state = 128'h5f9c6abfbac634aa50409fa766677653;
        @(posedge clk);
        assert (output_state == 128'hcfde0208f4b418ac5309db5c338538ed&& valid_data==1'b1);
        input_state = 128'h516604954353950314fb86e401922521;
        @(posedge clk);
        assert (output_state == 128'hd133f22a1aed2a7bfa0f44697c4f3ffd&& valid_data==1'b1);
        input_state = 128'h627bceb9999d5aaac945ecf423f56da5;
        @(posedge clk);
        assert (output_state == 128'haa218b56ee5ebeacdd6ecebf26e63c06&& valid_data==1'b1);  
        input_state = 128'h000102030405060708090a0b0c0d0e0f;
        @(posedge clk);
        assert (output_state == 128'h637c777bf26b6fc53001672bfed7ab76&& valid_data==1'b1);
        input_state = 128'h7a7b4e5638782546a8c0477a3b813f43;
        @(posedge clk);
        assert (output_state == 128'hda212fb107bc3f5ac2baa0dae20c751a&& valid_data==1'b1);
        input_state = 128'h6f2bd1c2be305b27578eb059fc490810;
        @(posedge clk);
        assert (output_state == 128'ha8f13e25ae0439cc5b19e7cbb03b30ca&& valid_data==1'b1);
        input_state = 128'h7c0994427bad065013fef7aa8789cf50;
        @(posedge clk);
        assert (output_state == 128'h1001222c21956f537dbb68ac17a78a53&& valid_data==1'b1);
        input_state = 128'h114d7f9b3d14fa62df93be5fedf43273;
        @(posedge clk);
        assert (output_state == 128'h82e3d21427fa2daa9edcaecf55bf238f&& valid_data==1'b1);
        input_state = 128'h46ea44846950ce2cf0c490c80588f739;
        @(posedge clk);
        assert (output_state == 128'h5a871b5ff9538b718c1c60e86bc46812&& valid_data==1'b1);
        input_state = 128'hf5187d8633814dcd516aa15e4bc59bf1;
        @(posedge clk);
        assert (output_state == 128'he6adff44c30ce3bdd1023258b3a614a1&& valid_data==1'b1);
        input_state = 128'h6deb4c2399f850272d9ed0e47e93e409;
        @(posedge clk);
        assert (output_state == 128'h3ce92926ee4153ccd80b7069f3dc6901&& valid_data==1'b1);
        input_state = 128'hc1f30e28571e544f9c9e5ca126211b49;
        @(posedge clk);
        assert (output_state == 128'h780dab345b722084de0b4a32f7fdaf3b&& valid_data==1'b1);
        input_state = 128'h528c75a627219aa6a450b40f94b56e41;
        @(posedge clk);
        assert (output_state == 128'h00649d24ccfdb82449538d7622d59f83&& valid_data==1'b1);
        input_state = 128'h6e2195717340289f5c866a2bf42e1089;
        @(posedge clk);
        assert (output_state == 128'h9ffd2aa38f0934db4a4402f1bf31caa7&& valid_data==1'b1);
        input_state = 128'h6b369a1a47499320e1283d220f5cc4aa;
        @(posedge clk);
        assert (output_state == 128'h7f05b8a2a03bdcb7f8342793764a1cac&& valid_data==1'b1);
        input_state = 128'h1d8d1baf22bb51a9b21ba041f6e26274;
        @(posedge clk);
        assert (output_state == 128'ha45daf7993ead1d337afe0834298aa92&& valid_data==1'b1);
        input_state = 128'h4a985e5badb8b7b9df72af79fcebf5bd;
        @(posedge clk);
        assert (output_state == 128'hd6465839956ca9569e4079b6b0e9e67a&& valid_data==1'b1);
        input_state = 128'h54686973497354686542657374506173;
        @(posedge clk);
        assert (output_state == 128'h2045f98f3b8f20454d2c4d8f9253ef8f&& valid_data==1'b1);
        input_state = 128'h7b0ad0d5068f1beabdea509e319c52ab;
        @(posedge clk);
        assert (output_state == 128'h216770036f73af877a87530bc7de0062&& valid_data==1'b1);
        input_state = 128'hccbc086b2ce6e3b47c17bdc2ea65f208;
        @(posedge clk);
        assert (output_state == 128'h4b65307f718e118d10f07a25874d8930&& valid_data==1'b1);
        input_state = 128'h66d869644816425873609269d907c3ef;
        @(posedge clk);
        assert (output_state == 128'h3361f94352472c6a8fd04ff935c52edf&& valid_data==1'b1);
        input_state = 128'h5d0fd04fa3fb55bdc59a38a6690933bb;
        @(posedge clk);
        assert (output_state == 128'h4c7670840a0ffc7aa6b80724f901c3ea&& valid_data==1'b1);
        input_state = 128'hca147537797dee1e9ebfbc393c8319dc;
        @(posedge clk);
        assert (output_state == 128'h74fa9d9ab6ff28720b086512ebecd486&& valid_data==1'b1);
        input_state = 128'he2d03b2ed3101d3e23b3d04062a8d858;
        @(posedge clk);
        assert (output_state == 128'h9870e23166caa4b2266d7009aac2616a&& valid_data==1'b1);
        input_state = 128'h17fc683db1f9a84c1b10b1f0bf3fcce8;
        @(posedge clk);
        assert (output_state == 128'hf0b04527c899c229afcac88c08754b9b&& valid_data==1'b1);
        input_state = 128'hde31a0f596c6ac02776dfaced4aad6a7;
        @(posedge clk);
        assert (output_state == 128'h1dc7e0e690b49177f53c2d8b48acf65c&& valid_data==1'b1);
        input_state = 128'h6c64806d15f9cf55a92af98035a58c6e;
        @(posedge clk);
        assert (output_state == 128'h5043cd3c59998afcd3e599cd9606649f&& valid_data==1'b1);
        input_state = 128'hf903fb020536c04b9c8f6a59eeb0c938;
        @(posedge clk);
        assert (output_state == 128'h997b0f776b05bab3de7302cb28e7dd07&& valid_data==1'b1);
        input_state = 128'hfa28c9ec4acadd4baa35f67cc207d949;
        @(posedge clk);
        assert (output_state == 128'h2d34ddced674c1b3ac96421025c5353b&& valid_data==1'b1);
        input_state = 128'hb667ce7f3f01cd54b1638984547c6865;
        @(posedge clk);
        assert (output_state == 128'h4e858bd2757cbd20c8fba75f2010454d&& valid_data==1'b1);
        input_state = 128'hf7059858cdc5bce335927f757da94c76;
        @(posedge clk);
        assert (output_state == 128'h686b466abda66511964fd29dffd32938&& valid_data==1'b1);
        input_state = 128'h1c0d051f26532307172e015254705b5a;
        @(posedge clk);
        assert (output_state == 128'h9cd76bc0f7ed26c5f0317c00205139be&& valid_data==1'b1);
        input_state = 128'hbe103f3b3b57acf0c87e4bc96a94f4f7;
        @(posedge clk);
        assert (output_state == 128'haeca75e2e25b918ce8f3b3dd0222bf68&& valid_data==1'b1);
        input_state = 128'h5b526a3defb8472a5262c4807f758778;
        @(posedge clk);
        assert (output_state == 128'h39000227df6ca0e500aa1ccdd29d17bc&& valid_data==1'b1);
        input_state = 128'h5553ba7527ed79c562f58e6b85b8a90f;
        @(posedge clk);
        assert (output_state == 128'hfcedf49dcc55b6a6aae6197f976cd376&& valid_data==1'b1);
        input_state = 128'h11b74108fdcb6568ae2de1eea59ba347;
        @(posedge clk);
        assert (output_state == 128'h82a98330541f4d45e4d8f82806140aa0&& valid_data==1'b1);
        input_state = 128'hc8aa900518179e26e9e657671e1d54b0;
        @(posedge clk);
        assert (output_state == 128'he8ac606badf00bf71e8e5b8572a420e7&& valid_data==1'b1);
        input_state = 128'h8f71776271ea7b98a9aff8db056ff3a8;
        @(posedge clk);
        assert (output_state == 128'h73a3f5aaa3872146d37941b96ba80dc2&& valid_data==1'b1);
        input_state = 128'h94764f2ceb3b174db7fc077a7d67049d;
        @(posedge clk);
        assert (output_state == 128'h22388471e9e2f0e3a9b0c5daff85f25e&& valid_data==1'b1);
        input_state = 128'h24c7477fb595640e7b02d07ac65637b3;
        @(posedge clk);
        assert (output_state == 128'h36c6a0d2d52a43ab217770dab4b19a6d&& valid_data==1'b1);
        input_state = 128'hefbedcb11aaa45d5a1d8cf1956673d00;
        @(posedge clk);
        assert (output_state == 128'hdfae86c8a2ac6e0332618ad4b1852763&& valid_data==1'b1);
        input_state = 128'h4c2f784dc8ef3e696f51844c7178fb6a;
        @(posedge clk);
        assert (output_state == 128'h2915bce3e8dfb2f9a8d15f29a3bc0f02&& valid_data==1'b1);
        input_state = 128'hacd516aaecefe4965271789a97aa1176;
        @(posedge clk);
        assert (output_state == 128'h910347accedf699000a3bcb888ac8238&& valid_data==1'b1);
        input_state = 128'hce8c3bf385d3333af08b06de4cf45a5d;
        @(posedge clk);
        assert (output_state == 128'h8b64e20d9766c3808c3d6f1d29bfbe4c&& valid_data==1'b1);
        input_state = 128'h81b6cfdc67790f469e88bd246bb99e76;
        @(posedge clk);
        assert (output_state == 128'h0c4e8a8685b6765a0bc47a367f560b38&& valid_data==1'b1);        
     
     
 
        
        $stop;
        $finish;
        
    end
    
    //set up clk signal to always flip-flop
    always #1 clk = ~clk; 
    
endmodule
