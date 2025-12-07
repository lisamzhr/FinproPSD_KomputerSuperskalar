
-- ============================================================================
-- COMPONENT 3: Control Signal Generator
-- Generate control signals dari opcode
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use work.superscalar_pkg.all;

entity control_signal_gen is
    port (
        opcode  : in std_logic_vector(3 downto 0);
        ctrl    : out std_logic_vector(13 downto 0)
    );
end entity control_signal_gen;

architecture rtl of control_signal_gen is
begin
    process(opcode)
    begin
        -- Format: [RAO,RAI,RBO,RBI,SUB,ALO,PCI,PCO,CNT,MRI,RMI,RMO,IRI,IRO]
        case opcode is
            when OP_NOP => ctrl <= "00000000100000";
            when OP_LDA => ctrl <= "01000000100100";
            when OP_STA => ctrl <= "10000000101000";
            when OP_ADD => ctrl <= "01000100100000";
            when OP_MAB => ctrl <= "00110000100000";
            when OP_LDB => ctrl <= "00010000100100";
            when OP_STB => ctrl <= "00100000101000";
            when OP_MBA => ctrl <= "01100000100000";
            when OP_JMP => ctrl <= "00000010000001";
            when OP_CMP => ctrl <= "00001000100000";
            when OP_SUB => ctrl <= "01001100100000";
            when OP_HLT => ctrl <= "00000000000000";
            when others => ctrl <= "00000000100000"; -- NOP
        end case;
    end process;
end architecture rtl;
