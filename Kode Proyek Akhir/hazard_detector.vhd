-- ============================================================================
-- COMPONENT 2: Hazard Detection Unit
-- Deteksi dependency antar instruksi
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use work.superscalar_pkg.all;

entity hazard_detector is
    port (
        res_instr_0 : in t_resource_usage;
        res_instr_1 : in t_resource_usage;
        hazard      : out std_logic
    );
end entity hazard_detector;

architecture rtl of hazard_detector is
begin
    process(res_instr_0, res_instr_1)
        variable v_hazard : std_logic;
    begin
        v_hazard := '0';
        
        -- RAW Hazard: Write-Read dependency
        if (res_instr_0.writes_A = '1' and res_instr_1.reads_A = '1') or
           (res_instr_0.writes_B = '1' and res_instr_1.reads_B = '1') then
            v_hazard := '1';
        end if;
        
        -- WAW Hazard: Write-Write dependency
        if (res_instr_0.writes_A = '1' and res_instr_1.writes_A = '1') or
           (res_instr_0.writes_B = '1' and res_instr_1.writes_B = '1') then
            v_hazard := '1';
        end if;
        
        -- WAR Hazard: Read-Write dependency
        if (res_instr_0.reads_A = '1' and res_instr_1.writes_A = '1') or
           (res_instr_0.reads_B = '1' and res_instr_1.writes_B = '1') then
            v_hazard := '1';
        end if;
        
        -- Structural Hazard: Resource conflict
        if (res_instr_0.uses_ALU = '1' and res_instr_1.uses_ALU = '1') or
           (res_instr_0.uses_memory = '1' and res_instr_1.uses_memory = '1') then
            v_hazard := '1';
        end if;
        
        -- Control Hazard: Branch or Halt
        if (res_instr_0.is_branch = '1' or res_instr_0.is_halt = '1') or
           (res_instr_1.is_branch = '1' or res_instr_1.is_halt = '1') then
            v_hazard := '1';
        end if;
        
        hazard <= v_hazard;
    end process;
end architecture rtl;