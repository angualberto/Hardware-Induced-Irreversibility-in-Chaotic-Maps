!==============================================================================
! AGLE - Gauss-Logistic Entropy Generator (Fortran Version)
! Objetivo: Refutacao Fisica do Determinismo via Deterioracao Aritmetica
!==============================================================================
program agle_fortran
    implicit none
    real(8) :: x, r, f_real, f_quant, epsilon
    real(4) :: f32
    integer(4) :: out_bytes
    integer(8) :: raw_bits
    integer :: i

    ! Parametros da Dinamica Nao Linear
    r = 3.99999999999999_8
    x = 0.12345678901234_8

    do
        ! 1. Calculo do Mapa no dominio Double (64-bit)
        f_real = r * x * (1.0_8 - x)

        ! 2. Forca a Deterioracao Aritmetica (Erro Fisico)
        f32 = real(f_real, 4)      ! Truncamento para Float (32-bit)
        f_quant = real(f32, 8)     ! Retorno para Double

        ! 3. Isola a Irreversibilidade (Residuo de Hardware)
        epsilon = f_real - f_quant

        ! 4. Feedback Caotico (Reinjeccao de Incerteza)
        x = abs(epsilon * 1.0d10)
        x = x - int(x)

        ! 5. XOR Fold + embaralhador leve (Xorshift + LCG + Xorshift)
        raw_bits = transfer(epsilon, raw_bits)
        ! Fold high/low of double to destroy IEEE exponent pattern
        out_bytes = ieor(int(raw_bits, 4), int(ishft(raw_bits, -32), 4))
        ! Xorshift round 1
        out_bytes = ieor(out_bytes, ishft(out_bytes, 13))
        out_bytes = ieor(out_bytes, ishft(out_bytes, -17))
        out_bytes = ieor(out_bytes, ishft(out_bytes, 5))
        ! LCG mix (Numerical Recipes constants)
        out_bytes = int(mod(int(z'0019660d',8) * int(out_bytes,8) + int(z'3c6ef35f',8), int(z'100000000',8)),4)
        ! Xorshift round 2 (different shift trio)
        out_bytes = ieor(out_bytes, ishft(out_bytes, 7))
        out_bytes = ieor(out_bytes, ishft(out_bytes, -9))
        out_bytes = ieor(out_bytes, ishft(out_bytes, 13))

        ! 6. Escrita Bruta (Streaming de Entropia)
        write(*, '(A4)', advance='no') transfer(out_bytes, "aaaa")
    end do
end program agle_fortran
