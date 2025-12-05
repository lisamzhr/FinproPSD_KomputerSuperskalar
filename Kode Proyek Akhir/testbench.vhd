library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use IEEE.std_logic_textio.all;

entity tb_superscalar_program is
end entity tb_superscalar_program;

architecture behavioral of tb_superscalar_program is

    -- COMPONENT: DUT

    component superscalar_control_unit is
        port (
            CLK             : in std_logic;
            RST             : in std_logic;
            enable          : in std_logic;
            opcode_0        : in std_logic_vector(3 downto 0);
            opcode_1        : in std_logic_vector(3 downto 0);
            operand_0       : in std_logic_vector(7 downto 0);
            operand_1       : in std_logic_vector(7 downto 0);
            carry_flag      : in std_logic;
            zero_flag       : in std_logic;
            ctrl_slot_0     : out std_logic_vector(13 downto 0);
            ctrl_slot_1     : out std_logic_vector(13 downto 0);
            slot_1_active   : out std_logic;
            stall           : out std_logic;
            branch_taken    : out std_logic
        );
    end component;

    -- KONSTANTA
    constant CLK_PERIOD : time := 10 ns;
    constant DATA_WIDTH : integer := 8;
    constant MEM_SIZE   : integer := 256;
    constant PROG_SIZE  : integer := 64;

    -- Opcode
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
    constant OP_SUB : std_logic_vector(3 downto 0) := "1100";
    constant OP_HLT : std_logic_vector(3 downto 0) := "1111";

    -- TIPE UNTUK PROGRAM MEMORY
    type t_instruction is record
        opcode  : std_logic_vector(3 downto 0);
        operand : unsigned(7 downto 0);
    end record;
    
    type t_program is array(0 to PROG_SIZE-1) of t_instruction;
    type t_data_mem is array(0 to MEM_SIZE-1) of unsigned(7 downto 0);

    -- SINYAL DUT
    signal clk           : std_logic := '0';
    signal rst           : std_logic := '1';
    signal enable        : std_logic := '1';
    signal opcode_0      : std_logic_vector(3 downto 0) := OP_NOP;
    signal opcode_1      : std_logic_vector(3 downto 0) := OP_NOP;
    signal operand_0     : std_logic_vector(7 downto 0) := x"00";
    signal operand_1     : std_logic_vector(7 downto 0) := x"00";
    signal carry_flag    : std_logic := '0';
    signal zero_flag     : std_logic := '0';
    signal ctrl_slot_0   : std_logic_vector(13 downto 0);
    signal ctrl_slot_1   : std_logic_vector(13 downto 0);
    signal slot_1_active : std_logic;
    signal stall         : std_logic;
    signal branch_taken  : std_logic;

    -- SIMULASI DATAPATH
    signal sim_reg_A   : unsigned(7 downto 0) := (others => '0');
    signal sim_reg_B   : unsigned(7 downto 0) := (others => '0');
    signal sim_PC      : integer := 0;
    signal sim_memory  : t_data_mem := (others => (others => '0'));
    
    -- Statistics
    signal cycle_count      : integer := 0;
    signal instr_count      : integer := 0;
    signal parallel_count   : integer := 0;
    signal sequential_count : integer := 0;

    -- File
    file report_file : text;

begin

    -- DUT
    DUT: superscalar_control_unit
        port map (
            CLK => clk, RST => rst, enable => enable,
            opcode_0 => opcode_0, opcode_1 => opcode_1,
            operand_0 => operand_0, operand_1 => operand_1,
            carry_flag => carry_flag, zero_flag => zero_flag,
            ctrl_slot_0 => ctrl_slot_0, ctrl_slot_1 => ctrl_slot_1,
            slot_1_active => slot_1_active, stall => stall, branch_taken => branch_taken
        );

    -- Clock
    clk <= not clk after CLK_PERIOD / 2;

    -- ========================================================================
    -- MAIN PROCESS
    -- ========================================================================
    STIMULUS: process
        variable L : line;
        variable file_status : file_open_status;
        variable temp : unsigned(8 downto 0);
        variable old_A, old_B : unsigned(7 downto 0);
        
        -- Program memory
        variable program : t_program := (others => (OP_NOP, x"00"));
        variable prog_len : integer := 0;

        -- HELPER FUNCTIONS
        function op_str(op : std_logic_vector(3 downto 0)) return string is
        begin
            case op is
                when "0000" => return "NOP ";
                when "0001" => return "LDA ";
                when "0010" => return "STA ";
                when "0011" => return "ADD ";
                when "0100" => return "MAB ";
                when "0101" => return "LDB ";
                when "0110" => return "STB ";
                when "0111" => return "MBA ";
                when "1000" => return "JMP ";
                when "1001" => return "CMP ";
                when "1100" => return "SUB ";
                when "1111" => return "HLT ";
                when others => return "??? ";
            end case;
        end function;

        procedure wr(s : string) is
        begin
            write(L, s);
            writeline(report_file, L);
        end procedure;

        procedure wr_sep is
        begin
            wr("================================================================================");
        end procedure;

        procedure wr_line is
        begin
            wr("--------------------------------------------------------------------------------");
        end procedure;

        -- ====================================================================
        -- EXECUTE SINGLE INSTRUCTION (Datapath Simulation)
        -- ====================================================================
        procedure exec_instr(
            op   : std_logic_vector(3 downto 0);
            addr : unsigned(7 downto 0);
            slot : string
        ) is
        begin
            write(L, string'("         "));
            write(L, slot);
            write(L, string'(": "));
            write(L, op_str(op));
            
            case op is
                when OP_NOP =>
                    write(L, string'("        (no operation)"));
                    
                when OP_LDA =>
                    old_A := sim_reg_A;
                    sim_reg_A <= sim_memory(to_integer(addr));
                    write(L, string'("["));
                    write(L, to_integer(addr));
                    write(L, string'("]     A: "));
                    write(L, to_integer(old_A));
                    write(L, string'(" -> "));
                    write(L, to_integer(sim_memory(to_integer(addr))));
                    
                when OP_LDB =>
                    old_B := sim_reg_B;
                    sim_reg_B <= sim_memory(to_integer(addr));
                    write(L, string'("["));
                    write(L, to_integer(addr));
                    write(L, string'("]     B: "));
                    write(L, to_integer(old_B));
                    write(L, string'(" -> "));
                    write(L, to_integer(sim_memory(to_integer(addr))));
                    
                when OP_STA =>
                    sim_memory(to_integer(addr)) <= sim_reg_A;
                    write(L, string'("["));
                    write(L, to_integer(addr));
                    write(L, string'("]     MEM["));
                    write(L, to_integer(addr));
                    write(L, string'("] <- "));
                    write(L, to_integer(sim_reg_A));
                    
                when OP_STB =>
                    sim_memory(to_integer(addr)) <= sim_reg_B;
                    write(L, string'("["));
                    write(L, to_integer(addr));
                    write(L, string'("]     MEM["));
                    write(L, to_integer(addr));
                    write(L, string'("] <- "));
                    write(L, to_integer(sim_reg_B));
                    
                when OP_ADD =>
                    old_A := sim_reg_A;
                    temp := ('0' & sim_reg_A) + ('0' & sim_reg_B);
                    sim_reg_A <= temp(7 downto 0);
                    carry_flag <= temp(8);
                    if temp(7 downto 0) = 0 then zero_flag <= '1'; else zero_flag <= '0'; end if;
                    write(L, string'("        A = "));
                    write(L, to_integer(old_A));
                    write(L, string'(" + "));
                    write(L, to_integer(sim_reg_B));
                    write(L, string'(" = "));
                    write(L, to_integer(temp(7 downto 0)));
                    
                when OP_SUB =>
                    old_A := sim_reg_A;
                    temp := ('0' & sim_reg_A) - ('0' & sim_reg_B);
                    sim_reg_A <= temp(7 downto 0);
                    carry_flag <= temp(8);
                    if temp(7 downto 0) = 0 then zero_flag <= '1'; else zero_flag <= '0'; end if;
                    write(L, string'("        A = "));
                    write(L, to_integer(old_A));
                    write(L, string'(" - "));
                    write(L, to_integer(sim_reg_B));
                    write(L, string'(" = "));
                    write(L, to_integer(temp(7 downto 0)));
                    
                when OP_MAB =>
                    old_B := sim_reg_B;
                    sim_reg_B <= sim_reg_A;
                    write(L, string'("        B <- A = "));
                    write(L, to_integer(sim_reg_A));
                    
                when OP_MBA =>
                    old_A := sim_reg_A;
                    sim_reg_A <= sim_reg_B;
                    write(L, string'("        A <- B = "));
                    write(L, to_integer(sim_reg_B));
                    
                when OP_CMP =>
                    if sim_reg_A = sim_reg_B then zero_flag <= '1'; else zero_flag <= '0'; end if;
                    if sim_reg_A < sim_reg_B then carry_flag <= '1'; else carry_flag <= '0'; end if;
                    write(L, string'("        A("));
                    write(L, to_integer(sim_reg_A));
                    write(L, string'(") vs B("));
                    write(L, to_integer(sim_reg_B));
                    write(L, string'(") Z="));
                    if sim_reg_A = sim_reg_B then write(L, string'("1")); else write(L, string'("0")); end if;
                    
                when OP_HLT =>
                    write(L, string'("        *** HALT ***"));
                    
                when others =>
                    write(L, string'("        (unknown)"));
            end case;
            
            writeline(report_file, L);
            instr_count <= instr_count + 1;
        end procedure;

        -- RUN PROGRAM
        procedure run_program(
            prog     : t_program;
            length   : integer;
            prog_name: string
        ) is
            variable pc : integer := 0;
            variable i0, i1 : t_instruction;
            variable is_parallel : boolean;
            variable hazard_str : string(1 to 20);
        begin
            sim_PC <= 0;
            pc := 0;
            
            wr("");
            wr_sep;
            write(L, string'("  RUNNING PROGRAM: "));
            write(L, prog_name);
            writeline(report_file, L);
            wr_sep;
            wr("");
            
            -- Print program listing
            wr("  [PROGRAM LISTING]");
            wr_line;
            for i in 0 to length-1 loop
                write(L, string'("    "));
                if i < 10 then write(L, string'(" ")); end if;
                write(L, i);
                write(L, string'(": "));
                write(L, op_str(prog(i).opcode));
                if prog(i).opcode = OP_LDA or prog(i).opcode = OP_LDB or 
                   prog(i).opcode = OP_STA or prog(i).opcode = OP_STB or
                   prog(i).opcode = OP_JMP then
                    write(L, string'("["));
                    write(L, to_integer(prog(i).operand));
                    write(L, string'("]"));
                end if;
                writeline(report_file, L);
            end loop;
            wr_line;
            wr("");
            
            -- Print initial state
            wr("  [INITIAL STATE]");
            write(L, string'("    Register A = "));
            write(L, to_integer(sim_reg_A));
            writeline(report_file, L);
            write(L, string'("    Register B = "));
            write(L, to_integer(sim_reg_B));
            writeline(report_file, L);
            write(L, string'("    Memory[50] = "));
            write(L, to_integer(sim_memory(50)));
            write(L, string'(", Memory[51] = "));
            write(L, to_integer(sim_memory(51)));
            write(L, string'(", Memory[52] = "));
            write(L, to_integer(sim_memory(52)));
            writeline(report_file, L);
            wr("");
            
            wr("  [EXECUTION TRACE]");
            wr_line;
            
            -- Execute program
            while pc < length loop
                cycle_count <= cycle_count + 1;
                
                -- Fetch 2 instructions
                i0 := prog(pc);
                if pc + 1 < length then
                    i1 := prog(pc + 1);
                else
                    i1 := (OP_NOP, x"00");
                end if;
                
                -- Send to DUT
                opcode_0 <= i0.opcode;
                opcode_1 <= i1.opcode;
                operand_0 <= std_logic_vector(i0.operand);
                operand_1 <= std_logic_vector(i1.operand);
                
                wait for CLK_PERIOD * 2;
                
                -- Check DUT decision
                is_parallel := (slot_1_active = '1');
                
                -- Log cycle
                write(L, string'("  CYCLE "));
                if cycle_count < 10 then write(L, string'(" ")); end if;
                write(L, cycle_count);
                write(L, string'(" | PC="));
                if pc < 10 then write(L, string'(" ")); end if;
                write(L, pc);
                write(L, string'(" | "));
                
                if is_parallel then
                    write(L, string'("[PARALLEL ] "));
                    write(L, op_str(i0.opcode));
                    write(L, string'("+ "));
                    write(L, op_str(i1.opcode));
                    parallel_count <= parallel_count + 1;
                else
                    write(L, string'("[SEQUENTIAL] "));
                    write(L, op_str(i0.opcode));
                    write(L, string'("      "));
                    sequential_count <= sequential_count + 1;
                end if;
                
                write(L, string'(" | A="));
                if to_integer(sim_reg_A) < 100 then write(L, string'(" ")); end if;
                if to_integer(sim_reg_A) < 10 then write(L, string'(" ")); end if;
                write(L, to_integer(sim_reg_A));
                write(L, string'(" B="));
                if to_integer(sim_reg_B) < 100 then write(L, string'(" ")); end if;
                if to_integer(sim_reg_B) < 10 then write(L, string'(" ")); end if;
                write(L, to_integer(sim_reg_B));
                writeline(report_file, L);
                
                -- Execute
                exec_instr(i0.opcode, i0.operand, "SLOT0");
                
                if is_parallel and pc + 1 < length then
                    exec_instr(i1.opcode, i1.operand, "SLOT1");
                    pc := pc + 2;
                else
                    pc := pc + 1;
                    -- Execute second instruction in next cycle if not parallel
                    if not is_parallel and pc < length then
                        wait for CLK_PERIOD;
                        cycle_count <= cycle_count + 1;
                    end if;
                end if;
                
                -- Check HLT
                if i0.opcode = OP_HLT then
                    exit;
                end if;
                
                wait for CLK_PERIOD;
            end loop;
            
            wr_line;
            wr("");
            
            -- Final state
            wr("  [FINAL STATE]");
            write(L, string'("    Register A = "));
            write(L, to_integer(sim_reg_A));
            writeline(report_file, L);
            write(L, string'("    Register B = "));
            write(L, to_integer(sim_reg_B));
            writeline(report_file, L);
            write(L, string'("    Memory[50] = "));
            write(L, to_integer(sim_memory(50)));
            write(L, string'(", Memory[51] = "));
            write(L, to_integer(sim_memory(51)));
            write(L, string'(", Memory[60] = "));
            write(L, to_integer(sim_memory(60)));
            writeline(report_file, L);
            write(L, string'("    Zero Flag  = "));
            write(L, zero_flag);
            write(L, string'(", Carry Flag = "));
            write(L, carry_flag);
            writeline(report_file, L);
            wr("");
            
        end procedure;

    begin

        -- OPEN FILE
        file_open(file_status, report_file, "superscalar_program_trace.txt", write_mode);
        
        -- Header
        wr_sep;
        wr("         SUPERSCALAR PROCESSOR - PROGRAM EXECUTION TRACE");
        wr("                    2-Way In-Order Issue");
        wr_sep;
        wr("");
        wr("  Testbench ini menjalankan program sequential dan menunjukkan");
        wr("  instruksi mana yang bisa dieksekusi PARALLEL vs SEQUENTIAL.");
        wr("");
        
        -- Reset
        rst <= '1';
        wait for CLK_PERIOD * 3;
        rst <= '0';
        wait for CLK_PERIOD;

        -- SETUP MEMORY
        sim_memory(50) <= to_unsigned(10, 8);   -- Value 10
        sim_memory(51) <= to_unsigned(20, 8);   -- Value 20
        sim_memory(52) <= to_unsigned(5, 8);    -- Value 5
        sim_memory(53) <= to_unsigned(15, 8);   -- Value 15
        sim_reg_A <= to_unsigned(0, 8);
        sim_reg_B <= to_unsigned(0, 8);

        -- ====================================================================
        -- PROGRAM 1: Simple Load and Add (dengan RAW hazard)
        -- ====================================================================
        program(0) := (OP_LDA, x"32");  -- LDA [50] -> A = 10
        program(1) := (OP_LDB, x"33");  -- LDB [51] -> B = 20  (SEQUENTIAL - STRUCTURAL memory)
        program(2) := (OP_ADD, x"00");  -- ADD      -> A = 30  (SEQUENTIAL - RAW butuh A,B baru)
        program(3) := (OP_STA, x"3C");  -- STA [60] -> M[60]=30 (SEQUENTIAL - RAW on A)
        program(4) := (OP_HLT, x"00");  -- HALT
        
        run_program(program, 5, "PROGRAM 1: Load and Add (RAW + STRUCTURAL Demo)");

        -- Reset untuk program berikutnya
        sim_reg_A <= to_unsigned(25, 8);
        sim_reg_B <= to_unsigned(15, 8);
        sim_memory(60) <= to_unsigned(0, 8);
        sim_memory(61) <= to_unsigned(0, 8);
        cycle_count <= 0;
        instr_count <= 0;
        parallel_count <= 0;
        sequential_count <= 0;
        wait for CLK_PERIOD * 2;

        -- ====================================================================
        -- PROGRAM 2: Perfect Parallelism (Independent register operations)
        -- ====================================================================
        program(0) := (OP_STA, x"3C");  -- STA [60] <- A (store 25)
        program(1) := (OP_STB, x"3D");  -- STB [61] <- B (store 15) - SEQUENTIAL (STRUCTURAL memory)
        program(2) := (OP_MAB, x"00");  -- MAB: B <- A (B = 25)
        program(3) := (OP_MBA, x"00");  -- MBA: A <- B (A = 15) - SEQUENTIAL (RAW + WAR on A, WAW + RAW on B)
        program(4) := (OP_HLT, x"00");  -- HALT
        
        run_program(program, 5, "PROGRAM 2: Store and Move (Multiple Hazards)");

        -- Reset
        sim_reg_A <= to_unsigned(100, 8);
        sim_reg_B <= to_unsigned(30, 8);
        sim_memory(50) <= to_unsigned(100, 8);
        sim_memory(51) <= to_unsigned(30, 8);
        sim_memory(52) <= to_unsigned(50, 8);
        cycle_count <= 0;
        instr_count <= 0;
        parallel_count <= 0;
        sequential_count <= 0;
        wait for CLK_PERIOD * 2;

        -- ====================================================================
        -- PROGRAM 3: Arithmetic Sequence (RAW Chain)
        -- ====================================================================
        program(0) := (OP_LDA, x"32");  -- LDA [50] -> A = 100
        program(1) := (OP_LDB, x"33");  -- LDB [51] -> B = 30   (SEQUENTIAL - STRUCTURAL memory)
        program(2) := (OP_ADD, x"00");  -- ADD -> A = 130       (SEQUENTIAL - RAW on A,B)
        program(3) := (OP_SUB, x"00");  -- SUB -> A = 100       (SEQUENTIAL - RAW on A, STRUCTURAL ALU)
        program(4) := (OP_MAB, x"00");  -- MAB -> B = 100       (SEQUENTIAL - RAW on A)
        program(5) := (OP_STA, x"3C");  -- STA [60] -> M[60]=100 (SEQUENTIAL - RAW on A)
        program(6) := (OP_STB, x"3D");  -- STB [61] -> M[61]=100 (SEQUENTIAL - STRUCTURAL memory + RAW on B)
        program(7) := (OP_HLT, x"00");
        
        run_program(program, 8, "PROGRAM 3: Arithmetic Sequence (Dense RAW Chain)");

        -- Reset
        sim_reg_A <= to_unsigned(50, 8);
        sim_reg_B <= to_unsigned(25, 8);
        sim_memory(50) <= to_unsigned(50, 8);
        sim_memory(51) <= to_unsigned(25, 8);
        sim_memory(52) <= to_unsigned(10, 8);
        sim_memory(53) <= to_unsigned(75, 8);
        cycle_count <= 0;
        instr_count <= 0;
        parallel_count <= 0;
        sequential_count <= 0;
        wait for CLK_PERIOD * 2;

        -- ====================================================================
        -- PROGRAM 4: WAR Hazard Demonstration
        -- ====================================================================
        program(0)  := (OP_STA, x"3C");  -- STA [60] <- A (50)
        program(1)  := (OP_STB, x"3D");  -- STB [61] <- B (25)  (SEQUENTIAL - STRUCTURAL memory)
        program(2)  := (OP_LDA, x"34");  -- LDA [52] -> A = 10  (SEQUENTIAL - WAR dari STA)
        program(3)  := (OP_LDB, x"35");  -- LDB [53] -> B = 75  (SEQUENTIAL - STRUCTURAL + WAR dari STB)
        program(4)  := (OP_ADD, x"00");  -- ADD -> A = 85       (SEQUENTIAL - RAW on A,B)
        program(5)  := (OP_CMP, x"00");  -- CMP A vs B          (SEQUENTIAL - RAW on A, STRUCTURAL ALU)
        program(6)  := (OP_STA, x"3E");  -- STA [62] <- A (85)  (SEQUENTIAL - RAW on A)
        program(7)  := (OP_HLT, x"00");
        
        run_program(program, 8, "PROGRAM 4: WAR and Memory Operations");

        -- Reset
        sim_reg_A <= to_unsigned(5, 8);
        sim_reg_B <= to_unsigned(3, 8);
        sim_memory(50) <= to_unsigned(5, 8);
        sim_memory(51) <= to_unsigned(3, 8);
        sim_memory(52) <= to_unsigned(7, 8);
        cycle_count <= 0;
        instr_count <= 0;
        parallel_count <= 0;
        sequential_count <= 0;
        wait for CLK_PERIOD * 2;

        -- ====================================================================
        -- PROGRAM 5: Register Move Chain (Dependency Chain)
        -- ====================================================================
        program(0) := (OP_LDA, x"32");  -- LDA [50] -> A = 5
        program(1) := (OP_LDB, x"33");  -- LDB [51] -> B = 3    (SEQUENTIAL - STRUCTURAL memory)
        program(2) := (OP_MAB, x"00");  -- MAB -> B = 5         (SEQUENTIAL - RAW on A, WAW on B)
        program(3) := (OP_MBA, x"00");  -- MBA -> A = 5         (SEQUENTIAL - RAW on B, WAW on A) 
        program(4) := (OP_ADD, x"00");  -- ADD -> A = 10        (SEQUENTIAL - RAW on A,B)
        program(5) := (OP_MAB, x"00");  -- MAB -> B = 10        (SEQUENTIAL - RAW on A, WAW on B)
        program(6) := (OP_STA, x"3C");  -- STA [60] <- A (10)   (SEQUENTIAL - RAW on A)
        program(7) := (OP_STB, x"3D");  -- STB [61] <- B (10)   (SEQUENTIAL - STRUCTURAL + RAW on B)
        program(8) := (OP_HLT, x"00");
        
        run_program(program, 9, "PROGRAM 5: Register Move Chain (Dense Dependencies)");
        
        -- Reset
        sim_reg_A <= to_unsigned(20, 8);
        sim_reg_B <= to_unsigned(40, 8);
        sim_memory(70) <= to_unsigned(0, 8);
        sim_memory(71) <= to_unsigned(0, 8);
        sim_memory(72) <= to_unsigned(0, 8);
        sim_memory(73) <= to_unsigned(0, 8);
        cycle_count <= 0;
        instr_count <= 0;
        parallel_count <= 0;
        sequential_count <= 0;
        wait for CLK_PERIOD * 2;

        -- ====================================================================
        -- PROGRAM 6: Best Case Parallelism (Independent Instructions)
        -- ====================================================================
        program(0) := (OP_STA, x"46");  -- STA [70] <- A (20)
        program(1) := (OP_STB, x"47");  -- STB [71] <- B (40)   (SEQUENTIAL - STRUCTURAL memory)
        program(2) := (OP_MAB, x"00");  -- MAB: B <- A (40)     (SEQUENTIAL - RAW on A, WAW on B)
        program(3) := (OP_STA, x"48");  -- STA [72] <- A (20)   (SEQUENTIAL - STRUCTURAL memory, WAR on A)
        program(4) := (OP_STB, x"49");  -- STB [73] <- B (20)   (SEQUENTIAL - STRUCTURAL memory, RAW on B)
        program(5) := (OP_HLT, x"00");
        
        run_program(program, 6, "PROGRAM 6: Store-Heavy Workload (Structural Hazards)");

        -- ====================================================================
        -- SUMMARY
        -- ====================================================================
        wr("");
        wr_sep;
        wr("                         EXECUTION SUMMARY");
        wr_sep;
        wr("");
        write(L, string'("  Total Instructions Executed : "));
        write(L, instr_count);
        writeline(report_file, L);
        write(L, string'("  Total Clock Cycles          : "));
        write(L, cycle_count);
        writeline(report_file, L);
        write(L, string'("  Parallel Executions         : "));
        write(L, parallel_count);
        writeline(report_file, L);
        write(L, string'("  Sequential Executions       : "));
        write(L, sequential_count);
        writeline(report_file, L);
        wr("");
        wr("  LEGEND:");
        wr("    [PARALLEL ]  = Kedua instruksi dieksekusi dalam 1 cycle");
        wr("    [SEQUENTIAL] = Hanya 1 instruksi dieksekusi (ada hazard)");
        wr("");
        wr("  HAZARD TYPES DEMONSTRATED:");
        wr("    - RAW: Read After Write (instr 2 baca register yg ditulis instr 1)");
        wr("    - WAW: Write After Write (kedua instr tulis register sama)");
        wr("    - WAR: Write After Read (instr 2 tulis register yg dibaca instr 1)");
        wr("    - STRUCTURAL: Kedua instr butuh resource sama (Memory/ALU)");
        wr("");
        wr_sep;
        wr("                          END OF TRACE");
        wr_sep;

        -- Close
        file_close(report_file);
        
        report "================================================";
        report "SIMULATION COMPLETE";
        report "Output: superscalar_program_trace.txt";
        report "Total Instructions: " & integer'image(instr_count);
        report "Total Cycles: " & integer'image(cycle_count);
        report "Parallel: " & integer'image(parallel_count);
        report "Sequential: " & integer'image(sequential_count);
        report "================================================";
        
        wait;
        
    end process STIMULUS;

end architecture behavioral;