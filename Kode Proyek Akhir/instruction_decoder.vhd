-- ============================================================================
-- COMPONENT 1: Instruction Decoder
-- Klasifikasi instruksi dan resource yang digunakan
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use work.superscalar_pkg.all;

entity instruction_decoder is
    port (
        opcode      : in std_logic_vector(3 downto 0);
        resources   : out t_resource_usage
    );
end entity instruction_decoder;

architecture rtl of instruction_decoder is
begin
    process(opcode)
        variable res : t_resource_usage;
    begin
        res := NULL_RESOURCE;
        
        case opcode is
            when OP_NOP =>
                null;
                
            when OP_LDA =>
                res.writes_A := '1';
                res.uses_memory := '1';
                
            when OP_LDB =>
                res.writes_B := '1';
                res.uses_memory := '1';
                
            when OP_STA =>
                res.reads_A := '1';
                res.uses_memory := '1';
                
            when OP_STB =>
                res.reads_B := '1';
                res.uses_memory := '1';
                
            when OP_ADD | OP_SUB | OP_CMP =>
                res.reads_A := '1';
                res.reads_B := '1';
                res.writes_A := '1';
                res.uses_ALU := '1';
                
            when OP_MAB =>
                res.reads_A := '1';
                res.writes_B := '1';
                
            when OP_MBA =>
                res.reads_B := '1';
                res.writes_A := '1';
                
            when OP_JMP | OP_JEQ | OP_JNE | OP_JC | OP_JNC =>
                res.is_branch := '1';
                
            when OP_HLT =>
                res.is_halt := '1';
                
            when others =>
                null;
        end case;
        
        resources <= res;
    end process;
end architecture rtl;
