library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- ============================================================================
-- PACKAGE: Common Types and Constants
-- ============================================================================
package superscalar_pkg is
    -- Opcode constants
    constant OP_NOP : std_logic_vector(3 downto 0) := "0000";
    constant OP_LDA : std_logic_vector(3 downto 0) := "0001";
    constant OP_STA : std_logic_vector(3 downto 0) := "0010";
    constant OP_ADD : std_logic_vector(3 downto 0) := "0011";
    constant OP_MAB : std_logic_vector(3 downto 0) := "0100";
    constant OP_LDB : std_logic_vector(3 downto 0) := "0101";
    constant OP_STB : std_logic_vector(3 downto 0) := "0110";
    constant OP_MBA : std_logic_vector(3 downto 0) := "0111";
    constant OP_JMP : std_logic_vector(3 downto 0) := "1000";
    constant OP_CMP : std_logic_vector(3 downto 0) := "1001";
    constant OP_JEQ : std_logic_vector(3 downto 0) := "1010";
    constant OP_JNE : std_logic_vector(3 downto 0) := "1011";
    constant OP_SUB : std_logic_vector(3 downto 0) := "1100";
    constant OP_JNC : std_logic_vector(3 downto 0) := "1101";
    constant OP_JC  : std_logic_vector(3 downto 0) := "1110";
    constant OP_HLT : std_logic_vector(3 downto 0) := "1111";
    
    -- Resource usage record
    type t_resource_usage is record
        reads_A     : std_logic;
        reads_B     : std_logic;
        writes_A    : std_logic;
        writes_B    : std_logic;
        uses_ALU    : std_logic;
        uses_memory : std_logic;
        is_branch   : std_logic;
        is_halt     : std_logic;
    end record;
    
    constant NULL_RESOURCE : t_resource_usage := (others => '0');
end package superscalar_pkg;

-- ============================================================================
-- Superscalar Control Unit
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use work.superscalar_pkg.all;

entity superscalar_control_unit is
    port (
        CLK             : in std_logic;
        RST             : in std_logic;
        enable          : in std_logic;
        
        -- Dual instruction inputs
        opcode_0        : in std_logic_vector(3 downto 0);
        opcode_1        : in std_logic_vector(3 downto 0);
        operand_0       : in std_logic_vector(7 downto 0);
        operand_1       : in std_logic_vector(7 downto 0);
        
        -- Flags
        carry_flag      : in std_logic;
        zero_flag       : in std_logic;
        
        -- Outputs
        ctrl_slot_0     : out std_logic_vector(13 downto 0);
        ctrl_slot_1     : out std_logic_vector(13 downto 0);
        slot_1_active   : out std_logic;
        stall           : out std_logic;
        branch_taken    : out std_logic
    );
end entity superscalar_control_unit;

architecture structural of superscalar_control_unit is
    
    -- Component declarations
    component instruction_decoder is
        port (
            opcode      : in std_logic_vector(3 downto 0);
            resources   : out t_resource_usage
        );
    end component;
    
    component hazard_detector is
        port (
            res_instr_0 : in t_resource_usage;
            res_instr_1 : in t_resource_usage;
            hazard      : out std_logic
        );
    end component;
    
    component control_signal_gen is
        port (
            opcode  : in std_logic_vector(3 downto 0);
            ctrl    : out std_logic_vector(13 downto 0)
        );
    end component;
    
    component branch_resolver is
        port (
            opcode       : in std_logic_vector(3 downto 0);
            zero_flag    : in std_logic;
            carry_flag   : in std_logic;
            branch_taken : out std_logic;
            is_halt      : out std_logic
        );
    end component;
    
    -- Internal signals
    signal res_0, res_1 : t_resource_usage;
    signal hazard_detected : std_logic;
    signal can_dual_issue : std_logic;
    signal ctrl_0, ctrl_1 : std_logic_vector(13 downto 0);
    signal branch_taken_internal : std_logic;
    signal is_halt_internal : std_logic;
    
begin
    
    -- ========================================================================
    -- Instantiate Instruction Decoders
    -- ========================================================================
    DECODER_0: instruction_decoder
        port map (
            opcode => opcode_0,
            resources => res_0
        );
    
    DECODER_1: instruction_decoder
        port map (
            opcode => opcode_1,
            resources => res_1
        );
    
    -- ========================================================================
    -- Instantiate Hazard Detector
    -- ========================================================================
    HAZARD_UNIT: hazard_detector
        port map (
            res_instr_0 => res_0,
            res_instr_1 => res_1,
            hazard => hazard_detected
        );
    
    can_dual_issue <= not hazard_detected;
    
    -- ========================================================================
    -- Instantiate Control Signal Generators
    -- ========================================================================
    CTRL_GEN_0: control_signal_gen
        port map (
            opcode => opcode_0,
            ctrl => ctrl_0
        );
    
    CTRL_GEN_1: control_signal_gen
        port map (
            opcode => opcode_1,
            ctrl => ctrl_1
        );
    
    -- ========================================================================
    -- Instantiate Branch Resolver
    -- ========================================================================
    BRANCH_UNIT: branch_resolver
        port map (
            opcode => opcode_0,
            zero_flag => zero_flag,
            carry_flag => carry_flag,
            branch_taken => branch_taken_internal,
            is_halt => is_halt_internal
        );
    
    -- ========================================================================
    -- Issue Logic (Sequential)
    -- ========================================================================
    ISSUE_PROCESS: process(CLK)
    begin
        if rising_edge(CLK) then
            if RST = '1' then
                ctrl_slot_0 <= (others => '0');
                ctrl_slot_1 <= (others => '0');
                slot_1_active <= '0';
                stall <= '0';
                branch_taken <= '0';
            elsif enable = '1' then
                -- Always issue instruction 0
                ctrl_slot_0 <= ctrl_0;
                
                -- Issue instruction 1 if no hazard
                if can_dual_issue = '1' then
                    ctrl_slot_1 <= ctrl_1;
                    slot_1_active <= '1';
                else
                    ctrl_slot_1 <= (others => '0');
                    slot_1_active <= '0';
                end if;
                
                -- Handle branch and halt
                branch_taken <= branch_taken_internal;
                stall <= is_halt_internal;
            end if;
        end if;
    end process ISSUE_PROCESS;
    
end architecture structural;