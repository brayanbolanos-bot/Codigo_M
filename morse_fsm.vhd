library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity morse_fsm is
    generic (
        HALF_COUNT : positive := 25000000
    );
    port (
        CLOCK_50 : in std_logic;
        KEY      : in std_logic_vector(1 downto 0);
        SW       : in std_logic_vector(2 downto 0);
        LEDR0    : out std_logic
    );
end morse_fsm;

architecture Behavior of morse_fsm is

    type state_type is (IDLE, LOAD, DOT, DASH1, DASH2, DASH3, GAP);
    signal y_Q, Y_D : state_type;

    signal reset_n    : std_logic;
    signal s0, s1, s2 : std_logic;
    signal start      : std_logic;

    signal pattern   : std_logic_vector(3 downto 0);
    signal length_in : unsigned(2 downto 0);

    signal sr      : std_logic_vector(3 downto 0);
    signal len_cnt : unsigned(2 downto 0);

    signal half_cnt : integer range 0 to HALF_COUNT - 1;
    signal timing   : std_logic;
    signal tick     : std_logic;

begin

    reset_n <= KEY(0);

    process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            s0 <= '1';
            s1 <= '1';
            s2 <= '1';
        elsif rising_edge(CLOCK_50) then
            s0 <= KEY(1);
            s1 <= s0;
            s2 <= s1;
        end if;
    end process;

    start <= s2 and (not s1);

    process (SW)
    begin
        case SW is
            when "000"  => pattern <= "0100"; length_in <= to_unsigned(2, 3);
            when "001"  => pattern <= "1000"; length_in <= to_unsigned(4, 3);
            when "010"  => pattern <= "1010"; length_in <= to_unsigned(4, 3);
            when "011"  => pattern <= "1000"; length_in <= to_unsigned(3, 3);
            when "100"  => pattern <= "0000"; length_in <= to_unsigned(1, 3);
            when "101"  => pattern <= "0010"; length_in <= to_unsigned(4, 3);
            when "110"  => pattern <= "1100"; length_in <= to_unsigned(3, 3);
            when others => pattern <= "0000"; length_in <= to_unsigned(4, 3);
        end case;
    end process;

    timing <= '1' when (y_Q = DOT or y_Q = DASH1 or y_Q = DASH2 or y_Q = DASH3 or y_Q = GAP) else '0';

    process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            half_cnt <= 0;
        elsif rising_edge(CLOCK_50) then
            if timing = '1' and half_cnt /= HALF_COUNT - 1 then
                half_cnt <= half_cnt + 1;
            else
                half_cnt <= 0;
            end if;
        end if;
    end process;

    tick <= '1' when (timing = '1' and half_cnt = HALF_COUNT - 1) else '0';

    process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            sr <= (others => '0');
            len_cnt <= (others => '0');
        elsif rising_edge(CLOCK_50) then
            if y_Q = LOAD then
                sr <= pattern;
                len_cnt <= length_in;
            elsif tick = '1' and (y_Q = DOT or y_Q = DASH3) then
                sr <= sr(2 downto 0) & '0';
                len_cnt <= len_cnt - 1;
            end if;
        end if;
    end process;

    process (y_Q, start, tick, pattern, sr, len_cnt)
    begin
        Y_D <= y_Q;
        case y_Q is
            when IDLE =>
                if start = '1' then
                    Y_D <= LOAD;
                end if;

            when LOAD =>
                if pattern(3) = '1' then
                    Y_D <= DASH1;
                else
                    Y_D <= DOT;
                end if;

            when DOT =>
                if tick = '1' then
                    if len_cnt = 1 then
                        Y_D <= IDLE;
                    else
                        Y_D <= GAP;
                    end if;
                end if;

            when DASH1 =>
                if tick = '1' then
                    Y_D <= DASH2;
                end if;

            when DASH2 =>
                if tick = '1' then
                    Y_D <= DASH3;
                end if;

            when DASH3 =>
                if tick = '1' then
                    if len_cnt = 1 then
                        Y_D <= IDLE;
                    else
                        Y_D <= GAP;
                    end if;
                end if;

            when GAP =>
                if tick = '1' then
                    if sr(3) = '1' then
                        Y_D <= DASH1;
                    else
                        Y_D <= DOT;
                    end if;
                end if;
        end case;
    end process;

    process (CLOCK_50, reset_n)
    begin
        if reset_n = '0' then
            y_Q <= IDLE;
        elsif rising_edge(CLOCK_50) then
            y_Q <= Y_D;
        end if;
    end process;

    LEDR0 <= '1' when (y_Q = DOT or y_Q = DASH1 or y_Q = DASH2 or y_Q = DASH3) else '0';

end Behavior;