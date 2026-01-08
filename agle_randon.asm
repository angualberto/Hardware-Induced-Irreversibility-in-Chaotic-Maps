; agle_randon.asm
; AGLE chaotic map with hardware-induced quantization error feedback
; Implements α-Gauss-Logistic map with floating-point arithmetic deterioration
; Build: nasm -felf64 -o agle_randon.o agle_randon.asm && ld -o agle_randon_asm agle_randon.o
; Run:   ./agle_randon_asm > out.bin   ; emits 4096 bytes per loop

BITS 64

%define SYS_write     1
%define SYS_exit      60
%define SYS_getrandom 318
%define STDOUT        1
%define BUF_SIZE      4096
%define ITERATIONS    1024       ; 1024 iterations * 4 bytes = 4096 bytes

section .data
    ; Parâmetros do mapa alfa-Gauss-Logístico
    r_val:      dq 3.999999999999     ; r próximo ao limite caótico
    lambda:     dq 3.0                ; Constante de reinjeção de erro
    one:        dq 1.0
    normalizer: dq 1.8446744073709552e19  ; 2^64 para normalização

section .bss
    buf:        resb BUF_SIZE
    x_state:    resq 1                ; Estado caótico persistente

section .text
global _start

_start:
    ; Inicializa estado caótico com getrandom
    mov     rax, SYS_getrandom
    lea     rdi, [rel x_state]
    mov     rsi, 8
    xor     rdx, rdx
    syscall
    test    rax, rax
    js      .exit
    
    ; Normaliza estado inicial para [0,1)
    movq    xmm0, [rel x_state]
    cvtsi2sd xmm0, qword [rel x_state]
    divsd   xmm0, [rel normalizer]
    movsd   [rel x_state], xmm0

.main_loop:
    ; Processa ITERATIONS pontos caóticos para preencher buf
    lea     rdi, [rel buf]
    mov     rcx, ITERATIONS
    
.chaos_loop:
    ; 1. Carrega estado atual
    movsd   xmm0, [rel x_state]       ; x
    
    ; 2. f_real = r * x * (1 - x)
    movsd   xmm2, [rel one]
    subsd   xmm2, xmm0                ; (1 - x)
    movsd   xmm1, [rel r_val]         ; r
    mulsd   xmm0, xmm1                ; r * x
    mulsd   xmm0, xmm2                ; f_real = r * x * (1 - x)
    
    ; 3. Captura o Erro de Quantização (Double -> Float -> Double)
    cvtsd2ss xmm3, xmm0               ; Converte Double -> Float (PERDE 29 bits)
    cvtss2sd xmm4, xmm3               ; Converte Float -> Double (quantizado)
    
    ; 4. Calcula erro: epsilon = f_real - f_quant
    movsd   xmm5, xmm0
    subsd   xmm5, xmm4                ; xmm5 = epsilon (erro físico)
    
    ; 5. Reinjeção com amplificação: x_new = f_quant + lambda * epsilon
    mulsd   xmm5, [rel lambda]        ; lambda * epsilon
    addsd   xmm4, xmm5                ; f_quant + lambda * epsilon
    
    ; 6. Normaliza para [0,1) com fmod
    movsd   xmm0, xmm4
    ; Implementação simplificada: x = x - floor(x)
    roundsd xmm1, xmm0, 0x01          ; floor(x)
    subsd   xmm0, xmm1                ; x - floor(x)
    
    ; 7. Salva novo estado
    movsd   [rel x_state], xmm0
    
    ; 8. Extração de Entropia (Fold + XOR para destruir padrão IEEE-754)
    ; Pega bits do estado caótico
    movq    rax, xmm0                 ; Double (64 bits) -> inteiro
    mov     rbx, rax
    shr     rbx, 32                   ; Parte alta (expoente + sinal)
    xor     eax, ebx                  ; XOR baixa ^ alta (32 bits)
    
    ; Pega bits do erro de quantização
    movq    rdx, xmm5                 ; Epsilon amplificado
    mov     r8, rdx
    shr     r8, 32
    xor     edx, r8d                  ; XOR erro baixo ^ erro alto (32 bits)
    
    ; Combina estado + erro
    xor     eax, edx                  ; Fold final: estado ^ erro
    
    ; Grava 4 bytes de entropia limpa
    mov     [rdi], eax
    add     rdi, 4
    
    loop    .chaos_loop
    
    ; 9. Escreve buffer completo no stdout
    mov     rax, SYS_write
    mov     rdi, STDOUT
    lea     rsi, [rel buf]
    mov     rdx, BUF_SIZE
    syscall
    test    rax, rax
    js      .exit
    
    jmp     .main_loop

.exit:
    mov     rax, SYS_exit
    xor     rdi, rdi
    syscall
