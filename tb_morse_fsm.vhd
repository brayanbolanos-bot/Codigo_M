LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY tb_morse_fsm IS
END tb_morse_fsm;

ARCHITECTURE sim OF tb_morse_fsm IS
    CONSTANT HALF   : positive := 20;
    CONSTANT T_CLK  : time     := 20 ns;
    CONSTANT T_HALF : time     := HALF * T_CLK;

    SIGNAL clk    : std_logic := '0';
    SIGNAL key    : std_logic_vector(1 DOWNTO 0) := "11";
    SIGNAL sw     : std_logic_vector(2 DOWNTO 0) := "000";
    SIGNAL led    : std_logic;
    SIGNAL errors : integer := 0;
BEGIN

    DUT : ENTITY work.morse_fsm
        GENERIC MAP (HALF_COUNT => HALF)
        PORT MAP (CLOCK_50 => clk, KEY => key, SW => sw, LEDR0 => led);

    clk <= NOT clk AFTER T_CLK / 2;

    PROCESS
        PROCEDURE press_start IS
        BEGIN
            key(1) <= '0';
            WAIT FOR 4 * T_CLK;
            key(1) <= '1';
        END PROCEDURE;

        PROCEDURE fail(msg : string) IS
        BEGIN
            errors <= errors + 1;
            REPORT "ERROR: " & msg SEVERITY error;
        END PROCEDURE;

        PROCEDURE check_letter(sel : std_logic_vector(2 DOWNTO 0); code : string; interrupt : boolean) IS
            VARIABLE t_rise, t_fall : time := 0 ns;
            VARIABLE expected       : time;
        BEGIN
            REPORT "Letra SW=" & std_logic'image(sel(2)) & std_logic'image(sel(1)) & std_logic'image(sel(0)) & "  codigo " & code;
            sw <= sel;
            press_start;
            
            FOR i IN code'RANGE LOOP
                WAIT UNTIL led = '1' FOR 20 * T_HALF;
                IF led /= '1' THEN
                    fail("no se encendio el LED en el simbolo " & integer'image(i));
                    RETURN;
                END IF;
                
                IF i > code'LEFT AND (now - t_fall) /= T_HALF THEN
                    fail("silencio entre simbolos incorrecto");
                END IF;
                
                t_rise := now;
                
                IF interrupt AND i = code'LEFT THEN
                    WAIT FOR T_HALF / 4;
                    sw <= "111";
                    press_start;
                END IF;
                
                WAIT UNTIL led = '0' FOR 5 * T_HALF;
                IF led /= '0' THEN
                    fail("el LED no se apago");
                    RETURN;
                END IF;
                
                t_fall := now;
                
                IF code(i) = '.' THEN 
                    expected := T_HALF; 
                ELSE 
                    expected := 3 * T_HALF; 
                END IF;
                
                IF (t_fall - t_rise) /= expected THEN
                    fail("ancho de pulso incorrecto en simbolo " & integer'image(i));
                END IF;
            END LOOP;

            WAIT UNTIL led = '1' FOR 4 * T_HALF;
            IF led = '1' THEN 
                fail("pulso extra despues de la letra"); 
            END IF;
            WAIT FOR 2 * T_HALF;
        END PROCEDURE;
        
    BEGIN
        key(0) <= '0';
        WAIT FOR 3 * T_CLK;
        key(0) <= '1';
        WAIT FOR 3 * T_CLK;

        check_letter("000", ".-",   false);
        check_letter("001", "-...", false);
        check_letter("010", "-.-.", false);
        check_letter("011", "-..",  false);
        check_letter("100", ".",    false);
        check_letter("101", "..-.", false);
        check_letter("110", "--.",  false);
        check_letter("111", "....", false);

        check_letter("000", ".-",   true);

        REPORT "Prueba de reset asincrono";
        sw <= "001";
        press_start;
        WAIT UNTIL led = '1' FOR 20 * T_HALF;
        WAIT FOR T_HALF / 2;
        key(0) <= '0';
        WAIT FOR 1 ns;
        
        IF led /= '0' THEN 
            fail("el reset asincrono no apago el LED"); 
        END IF;
        
        WAIT FOR 2 * T_CLK;
        key(0) <= '1';
        WAIT FOR 6 * T_HALF;
        
        IF led /= '0' THEN 
            fail("hubo salida despues del reset"); 
        END IF;

        IF errors = 0 THEN
            REPORT "TODAS LAS PRUEBAS PASARON" SEVERITY note;
        ELSE
            REPORT "FALLARON " & integer'image(errors) & " PRUEBAS" SEVERITY failure;
        END IF;
        WAIT;
    END PROCESS;
END sim;

