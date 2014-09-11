//======================================================================
//
// trng_mixer.v
// ------------
// Mixer for the TRNG.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module trng_mixer(
                  // Clock and reset.
                  input wire           clk,
                  input wire           reset_n,

                  // Controls.
                  input wire           enable,
                  input wire           more_seed,

                  input wire           entropy0_enabled,
                  input wire           entropy0_syn,
                  output wire          entropy0_ack,

                  input wire           entropy1_enabled,
                  input wire           entropy1_syn,
                  output wire          entropy1_ack,

                  input wire           entropy2_enabled,
                  input wire           entropy2_syn,
                  output wire          entropy2_ack,

                  output wire [511 : 0] seed_data,
                  output wire           seed_syn,
                  input wire            seed_ack
                 );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter MODE_SHA_512 = 2'h3;

  parameter CTRL_IDLE    = 4'h0;
  parameter CTRL_COLLECT = 4'h1;
  parameter CTRL_MIX     = 4'h2;
  parameter CTRL_SYN     = 4'h3;
  parameter CTRL_ACK     = 4'h4;
  parameter CTRL_NEXT    = 4'h5;
  parameter CTRL_CANCEL  = 4'hf;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] block00_reg;
  reg [31 : 0] block00_we;
  reg [31 : 0] block01_reg;
  reg [31 : 0] block01_we;
  reg [31 : 0] block02_reg;
  reg [31 : 0] block02_we;
  reg [31 : 0] block03_reg;
  reg [31 : 0] block03_we;
  reg [31 : 0] block04_reg;
  reg [31 : 0] block04_we;
  reg [31 : 0] block05_reg;
  reg [31 : 0] block05_we;
  reg [31 : 0] block06_reg;
  reg [31 : 0] block06_we;
  reg [31 : 0] block07_reg;
  reg [31 : 0] block07_we;
  reg [31 : 0] block08_reg;
  reg [31 : 0] block08_we;
  reg [31 : 0] block09_reg;
  reg [31 : 0] block09_we;
  reg [31 : 0] block10_reg;
  reg [31 : 0] block10_we;
  reg [31 : 0] block11_reg;
  reg [31 : 0] block11_we;
  reg [31 : 0] block12_reg;
  reg [31 : 0] block12_we;
  reg [31 : 0] block13_reg;
  reg [31 : 0] block13_we;
  reg [31 : 0] block14_reg;
  reg [31 : 0] block14_we;
  reg [31 : 0] block15_reg;
  reg [31 : 0] block15_we;
  reg [31 : 0] block16_reg;
  reg [31 : 0] block16_we;
  reg [31 : 0] block17_reg;
  reg [31 : 0] block17_we;
  reg [31 : 0] block18_reg;
  reg [31 : 0] block18_we;
  reg [31 : 0] block19_reg;
  reg [31 : 0] block19_we;
  reg [31 : 0] block20_reg;
  reg [31 : 0] block20_we;
  reg [31 : 0] block21_reg;
  reg [31 : 0] block21_we;
  reg [31 : 0] block22_reg;
  reg [31 : 0] block22_we;
  reg [31 : 0] block23_reg;
  reg [31 : 0] block23_we;
  reg [31 : 0] block24_reg;
  reg [31 : 0] block24_we;
  reg [31 : 0] block25_reg;
  reg [31 : 0] block25_we;
  reg [31 : 0] block26_reg;
  reg [31 : 0] block26_we;
  reg [31 : 0] block27_reg;
  reg [31 : 0] block27_we;
  reg [31 : 0] block28_reg;
  reg [31 : 0] block28_we;
  reg [31 : 0] block29_reg;
  reg [31 : 0] block29_we;
  reg [31 : 0] block30_reg;
  reg [31 : 0] block30_we;
  reg [31 : 0] block31_reg;
  reg [31 : 0] block31_we;

  reg [4 : 0] word_ctr_reg;
  reg [4 : 0] word_ctr_new;
  reg         word_ctr_inc;
  reg         word_ctr_rst;
  reg         word_ctr_we;

  reg [3 : 0] mixer_ctrl_reg;
  reg [3 : 0] mixer_ctrl_new;
  reg         mixer_ctrl_we;

  reg         seed_syn_reg;
  reg         seed_syn_new;
  reg         seed_syn_we;

  reg         init_done_reg;
  reg         init_done_new;
  reg         init_done_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0]    muxed_entropy;
  reg             muxed_entropy_syn;
  reg             update_block;
  reg             mux_entropy;

  reg             hash_init;
  reg             hash_next;

  wire [1023 : 0] hash_block;
  wire            hash_ready;
  wire [511 : 0]  hash_digest;
  wire            hash_digest_valid;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign seed_data = hash_digest;

  assign hash_block = {block00_reg, block01_reg, block02_reg, block03_reg,
                       block04_reg, block05_reg, block06_reg, block07_reg,
                       block08_reg, block09_reg,
                       block10_reg, block11_reg, block12_reg, block13_reg,
                       block14_reg, block15_reg, block16_reg, block17_reg,
                       block18_reg, block19_reg,
                       block20_reg, block21_reg, block22_reg, block23_reg,
                       block24_reg, block25_reg, block26_reg, block27_reg,
                       block28_reg, block29_reg,
                       block30_reg, block31_reg};


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  sha512_core hash(
                   .clk(clk),
                   .reset_n(reset_n),

                   .init(hash_init),
                   .next(hash_next),
                   .mode(MODE_SHA_512),

                   .block(hash_block),

                   .ready(hash_ready),
                   .digest(hash_digest),
                   .digest_valid(hash_digest_valid)
                  );


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          block00_reg    <= 32'h00000000;
          block01_reg    <= 32'h00000000;
          block02_reg    <= 32'h00000000;
          block03_reg    <= 32'h00000000;
          block04_reg    <= 32'h00000000;
          block05_reg    <= 32'h00000000;
          block06_reg    <= 32'h00000000;
          block07_reg    <= 32'h00000000;
          block08_reg    <= 32'h00000000;
          block09_reg    <= 32'h00000000;
          block10_reg    <= 32'h00000000;
          block11_reg    <= 32'h00000000;
          block12_reg    <= 32'h00000000;
          block13_reg    <= 32'h00000000;
          block14_reg    <= 32'h00000000;
          block15_reg    <= 32'h00000000;
          block16_reg    <= 32'h00000000;
          block17_reg    <= 32'h00000000;
          block18_reg    <= 32'h00000000;
          block19_reg    <= 32'h00000000;
          block20_reg    <= 32'h00000000;
          block21_reg    <= 32'h00000000;
          block22_reg    <= 32'h00000000;
          block23_reg    <= 32'h00000000;
          block24_reg    <= 32'h00000000;
          block25_reg    <= 32'h00000000;
          block26_reg    <= 32'h00000000;
          block27_reg    <= 32'h00000000;
          block28_reg    <= 32'h00000000;
          block29_reg    <= 32'h00000000;
          block30_reg    <= 32'h00000000;
          block31_reg    <= 32'h00000000;
          seed_syn_reg   <= 0;
          mixer_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (block00_we)
            begin
              block00_reg <= muxed_entropy;
            end

          if (block01_we)
            begin
              block01_reg <= muxed_entropy;
            end

          if (block02_we)
            begin
              block02_reg <= muxed_entropy;
            end

          if (block03_we)
            begin
              block03_reg <= muxed_entropy;
            end

          if (block04_we)
            begin
              block04_reg <= muxed_entropy;
            end

          if (block05_we)
            begin
              block05_reg <= muxed_entropy;
            end

          if (block06_we)
            begin
              block06_reg <= muxed_entropy;
            end

          if (block07_we)
            begin
              block07_reg <= muxed_entropy;
            end

          if (block08_we)
            begin
              block08_reg <= muxed_entropy;
            end

          if (block09_we)
            begin
              block09_reg <= muxed_entropy;
            end

          if (block10_we)
            begin
              block10_reg <= muxed_entropy;
            end

          if (block11_we)
            begin
              block11_reg <= muxed_entropy;
            end

          if (block12_we)
            begin
              block12_reg <= muxed_entropy;
            end

          if (block13_we)
            begin
              block13_reg <= muxed_entropy;
            end

          if (block14_we)
            begin
              block14_reg <= muxed_entropy;
            end

          if (block15_we)
            begin
              block15_reg <= muxed_entropy;
            end

          if (block16_we)
            begin
              block16_reg <= muxed_entropy;
            end

          if (block17_we)
            begin
              block17_reg <= muxed_entropy;
            end

          if (block18_we)
            begin
              block18_reg <= muxed_entropy;
            end

          if (block19_we)
            begin
              block19_reg <= muxed_entropy;
            end

          if (block20_we)
            begin
              block20_reg <= muxed_entropy;
            end

          if (block21_we)
            begin
              block21_reg <= muxed_entropy;
            end

          if (block22_we)
            begin
              block22_reg <= muxed_entropy;
            end

          if (block23_we)
            begin
              block23_reg <= muxed_entropy;
            end

          if (block24_we)
            begin
              block24_reg <= muxed_entropy;
            end

          if (block25_we)
            begin
              block25_reg <= muxed_entropy;
            end

          if (block26_we)
            begin
              block26_reg <= muxed_entropy;
            end

          if (block27_we)
            begin
              block27_reg <= muxed_entropy;
            end

          if (block28_we)
            begin
              block28_reg <= muxed_entropy;
            end

          if (block29_we)
            begin
              block29_reg <= muxed_entropy;
            end

          if (block30_we)
            begin
              block30_reg <= muxed_entropy;
            end

          if (block31_we)
            begin
              block31_reg <= muxed_entropy;
            end

          if (mixer_ctrl_we)
            begin
              mixer_ctrl_reg <= mixer_ctrl_new;
            end

          if (seed_syn_we)
            begin
              seed_syn_reg <= seed_syn_we;
            end

          if (init_done_we)
            begin
              init_done_reg <= init_done_we;
            end
        end
    end // reg_update

  //----------------------------------------------------------------
  // entropy_mux
  //
  // This is a round-robin mux that muxes the signals from
  // the entropy sources that are enabled.
  //----------------------------------------------------------------
  always @*
    begin : entropy_mux
    end // entropy_mux


  //----------------------------------------------------------------
  // word_mux
  //----------------------------------------------------------------
  always @*
    begin : word_mux
      block00_we = 0;
      block01_we = 0;
      block02_we = 0;
      block03_we = 0;
      block04_we = 0;
      block05_we = 0;
      block06_we = 0;
      block07_we = 0;
      block08_we = 0;
      block09_we = 0;
      block10_we = 0;
      block11_we = 0;
      block12_we = 0;
      block13_we = 0;
      block14_we = 0;
      block15_we = 0;
      block16_we = 0;
      block17_we = 0;
      block18_we = 0;
      block19_we = 0;
      block20_we = 0;
      block21_we = 0;
      block22_we = 0;
      block23_we = 0;
      block24_we = 0;
      block25_we = 0;
      block26_we = 0;
      block27_we = 0;
      block28_we = 0;
      block29_we = 0;
      block30_we = 0;
      block31_we = 0;

      if (update_block)
        begin
          case (word_ctr_reg)
            00 : block00_we = 1;
            01 : block01_we = 1;
            02 : block02_we = 1;
            03 : block03_we = 1;
            04 : block04_we = 1;
            05 : block05_we = 1;
            06 : block06_we = 1;
            07 : block07_we = 1;
            08 : block08_we = 1;
            09 : block09_we = 1;
            10 : block10_we = 1;
            11 : block11_we = 1;
            12 : block12_we = 1;
            13 : block13_we = 1;
            14 : block14_we = 1;
            15 : block15_we = 1;
            16 : block16_we = 1;
            17 : block17_we = 1;
            18 : block18_we = 1;
            19 : block19_we = 1;
            20 : block20_we = 1;
            21 : block21_we = 1;
            22 : block22_we = 1;
            23 : block23_we = 1;
            24 : block24_we = 1;
            25 : block25_we = 1;
            26 : block26_we = 1;
            27 : block27_we = 1;
            28 : block28_we = 1;
            29 : block29_we = 1;
            30 : block30_we = 1;
            31 : block31_we = 1;
          endcase // case (word_ctr_reg)
        end
    end // word_mux


  //----------------------------------------------------------------
  // word_ctr
  //----------------------------------------------------------------
  always @*
    begin : word_ctr
      word_ctr_new = 5'h00;
      word_ctr_we  = 0;

      if (word_ctr_rst)
        begin
          word_ctr_new = 5'h00;
          word_ctr_we  = 1;
        end

      if (word_ctr_inc)
        begin
          word_ctr_new = word_ctr_reg + 1'b1;
          word_ctr_we  = 1;
        end
    end // word_ctr


  //----------------------------------------------------------------
  // mixer_ctrl_fsm
  //
  // Control FSM for the mixer.
  //----------------------------------------------------------------
  always @*
    begin : mixer_ctrl_fsm
      word_ctr_inc   = 0;
      word_ctr_rst   = 0;
      seed_syn_new   = 0;
      seed_syn_we    = 0;
      init_done_new  = 0;
      init_done_we   = 0;
      hash_init      = 0;
      hash_next      = 0;
      mux_entropy    = 0;
      update_block   = 0;
      mixer_ctrl_new = CTRL_IDLE;
      mixer_ctrl_we  = 0;

      case (mixer_ctrl_reg)
        CTRL_IDLE:
          begin
            if (!enable)
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
            else if (more_seed)
              begin
                word_ctr_rst   = 1;
                init_done_new  = 0;
                init_done_we   = 1;
                mixer_ctrl_new = CTRL_COLLECT;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_COLLECT:
          begin
            if ((!enable))
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
            else
              begin
                mux_entropy = 1;
                if (word_ctr_reg == 5'h1f)
                  begin
                    mixer_ctrl_new = CTRL_MIX;
                    mixer_ctrl_we  = 1;
                  end
                else
                  begin
                    if (muxed_entropy_syn)
                      begin
                        word_ctr_inc = 1;
                      end
                  end
              end
          end

        CTRL_MIX:
          begin
            if ((!enable))
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
            else
              begin
                if (init_done_reg)
                  begin
                    hash_next = 1;
                  end
                else
                  begin
                    hash_init = 1;
                  end
                mixer_ctrl_new = CTRL_SYN;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_SYN:
          begin
            if ((!enable))
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
            else if (hash_ready)
              begin
                seed_syn_new   = 1;
                seed_syn_we    = 1;
                mixer_ctrl_new = CTRL_ACK;
                mixer_ctrl_we  = 1;
              end

          end

        CTRL_ACK:
          begin
            if ((!enable))
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
            else if (seed_ack)
              begin
                seed_syn_new   = 0;
                seed_syn_we    = 1;
                mixer_ctrl_new = CTRL_NEXT;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_NEXT:
          begin
            if ((!enable))
              begin
                mixer_ctrl_new = CTRL_CANCEL;
                mixer_ctrl_we  = 1;
              end
            else if (more_seed)
              begin
                word_ctr_rst   = 1;
                init_done_new  = 1;
                init_done_we   = 1;
                mixer_ctrl_new = CTRL_COLLECT;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_CANCEL:
          begin
            mixer_ctrl_new  = CTRL_IDLE;
            mixer_ctrl_we   = 1;
          end

      endcase // case (cspng_ctrl_reg)
    end // mixer_ctrl_fsm

endmodule // trng_mixer

//======================================================================
// EOF trng_mixer.v
//======================================================================
