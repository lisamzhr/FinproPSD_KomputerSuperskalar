# Computer Superscalar 

## Overview
Implementasi prosesor superscalar dengan arsitektur 2-way in-order issue yang mampu mengeksekusi dua instruksi secara paralel dalam satu clock cycle, dilengkapi hazard detection unit untuk menangani dependency antar instruksi.

---

## Komponen Utama

### 1. Package Definition
Definisi tipe data dan konstanta untuk resource tracking.

```vhdl
type t_resource_usage is record
    reads_A, reads_B     : std_logic;
    writes_A, writes_B   : std_logic;
    uses_ALU, uses_memory : std_logic;
    is_branch, is_halt   : std_logic;
end record;
```

### 2. Instruction Decoder
Menganalisis opcode dan menentukan resource usage instruksi.

```vhdl
when OP_ADD =>
    resources.reads_A <= '1';
    resources.reads_B <= '1';
    resources.writes_A <= '1';
    resources.uses_ALU <= '1';
```

### 3. Hazard Detection Unit
Deteksi 5 jenis hazard secara paralel untuk dua instruksi.

**Jenis Hazard:**
- RAW (Read After Write)
- WAW (Write After Write)
- WAR (Write After Read)
- Structural (Resource conflict)
- Control (Branch/Halt)

### 4. Control Signal Generator
Generate 14-bit control signal untuk datapath.

```vhdl
-- Format: [RAO,RAI,RBO,RBI,SUB,ALO,PCI,PCO,CNT,MRI,RMI,RMO,IRI,IRO]
when OP_LDA => ctrl <= "01000000100100";
when OP_ADD => ctrl <= "01000100100000";
```

### 5. Branch Resolver
Menentukan branch decision berdasarkan flags.

```vhdl
when OP_JEQ => branch_taken <= zero_flag;
when OP_JNE => branch_taken <= not zero_flag;
when OP_JC  => branch_taken <= carry_flag;
when OP_HLT => is_halt <= '1';
```

### 6. Superscalar Control Unit
Top-level dengan arsitektur structural.

```vhdl
-- Issue Logic
if can_dual_issue = '1' then
    ctrl_slot_1 <= ctrl_1;
    slot_1_active <= '1';
else
    ctrl_slot_1 <= (others => '0');
    slot_1_active <= '0';
end if;
```

---

## Simulasi & Testing

**Test Programs:**
1. **Load and Add** - RAW + structural hazard (full sequential)
2. **Store and Move** - Multiple hazards (full sequential)
3. **Arithmetic Sequence** - **Parallel execution** MAB || STA di cycle 9
4. **WAR and Memory** - WAR hazard (full sequential)

**Hasil:**
- Program 3 mencapai dual-issue execution
- Speedup 12 cycle vs 14 cycle sequential
- Correctness terjaga pada semua test case

**Contoh Output:**
```
CYCLE  9 | PC= 4 | [PARALLEL ] MAB + STA
       SLOT0: MAB         B <- A = 100
       SLOT1: STA [60]     MEM[60] <- 100
```
