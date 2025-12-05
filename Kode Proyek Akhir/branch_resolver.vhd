-- ============================================================================
-- COMPONENT 4: Branch Resolution Unit
-- Menentukan branch diambil
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use work.superscalar_pkg.all;

entity branch_resolver is
    port (
        opcode       : in std_logic_vector(3 downto 0);
        zero_flag    : in std_logic;
        carry_flag   : in std_logic;
        branch_taken : out std_logic;
        is_halt      : out std_logic
    );
end entity branch_resolver;

architecture rtl of branch_resolver is
begin
    process(opcode, zero_flag, carry_flag)
    begin
        branch_taken <= '0';
        is_halt <= '0';
        
        case opcode is
            when OP_JMP => 
                branch_taken <= '1';
            when OP_JEQ => 
                branch_taken <= zero_flag;
            when OP_JNE => 
                branch_taken <= not zero_flag;
            when OP_JC => 
                branch_taken <= carry_flag;
            when OP_JNC => 
                branch_taken <= not carry_flag;
            when OP_HLT =>
                is_halt <= '1';
            when others =>
                null;
        end case;
    end process;
end architecture rtl;
