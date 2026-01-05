#include <stdio.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

/* AGLE - Algoritmo Canônico com Física de Ponto Flutuante
 * Realimentação de erro para inserir incerteza na equação
 */

typedef struct {
    double r;           /* parâmetro de não-linearidade: r > 0 (ex: 3.9999) */
    double alpha;       /* expoente de singularidade: α ≥ 0 (ex: 1.0) */
    double lambda;      /* realimentação do erro: λ > 0 (ex: 1.0) */
    double x;           /* estado caótico em [0,1) */
    double epsilon_acc; /* acumulador de erro para amplificação */
} AGLE;

/* Inicializa o AGLE */
void agle_init(AGLE *gen, double r, double alpha, double lambda, double x0) {
    gen->r = r;
    gen->alpha = alpha;
    gen->lambda = lambda;
    gen->x = x0;
    gen->epsilon_acc = 0.0;
}

/* Gera um uint32 usando física de ponto flutuante com acumulação de erro */
uint32_t agle_next(AGLE *gen) {
    uint32_t result = 0;
    
    /* 4 iterações internas para amplificar caos */
    for (int iter = 0; iter < 4; iter++) {
        /* 1. Cálculo em precisão real (dupla) com epsilon acumulado */
        double f_real = gen->r * gen->x * (1.0 - gen->x) * pow(gen->x, -gen->alpha);
        
        /* 2-3. Quantização IEEE-754 FÍSICA (double → float → double) */
        volatile float f32 = (float) f_real;  /* força quantização: perde 29 bits */
        double f_quant = (double) f32;        /* volta quantizado */
        
        /* Erro físico de arredondamento (IRREVERSÍVEL!) */
        double epsilon = f_real - f_quant;    /* diferença real */
        
        /* 4. Acumula erro para amplificação (retroalimentação no sistema) */
        gen->epsilon_acc = (gen->epsilon_acc + epsilon) - floor(gen->epsilon_acc + epsilon);
        
        /* 5. Mapa α-Gauss-Logístico com injeção de erro acumulado */
        double y = f_quant - floor(f_quant);
        
        /* 6. Realimentação dupla com combinação não-linear */
        gen->x = y + gen->lambda * epsilon + (gen->lambda * 0.3) * gen->epsilon_acc;
        gen->x = gen->x - floor(gen->x);
        
        /* 7. Extração de bits de cada iteração */
        uint64_t raw;
        memcpy(&raw, &gen->x, sizeof(uint64_t));
        uint32_t mantissa = (uint32_t)((raw >> 12) & 0xFFFFFFFFUL);
        
        /* Pega bits de epsilon */
        uint64_t eps_raw;
        memcpy(&eps_raw, &epsilon, sizeof(uint64_t));
        uint32_t eps_bits = (uint32_t)(eps_raw & 0xFFFFFFFFUL);
        
        /* Combina iterações com XOR */
        result ^= (mantissa ^ eps_bits);
    }
    
    return result;
}

int main(void) {
    /* Parâmetros do AGLE */
    double r = 3.9999;    /* regime fortemente caótico */
    double alpha = 1.0;   /* singularidade típica */
    double lambda = 3.0;  /* realimentação amplificada para inserir mais erro */
    double x0 = 0.123456789; /* estado inicial (reprodutível) */
    
    AGLE gen;
    agle_init(&gen, r, alpha, lambda, x0);
    
    /* Gera e emite números de 32 bits para dieharder */
    uint32_t buffer[512];
    
    while (1) {
        for (int i = 0; i < 512; i++) {
            buffer[i] = agle_next(&gen);
        }
        /* Escreve 512 * 4 = 2048 bytes em formato binário */
        fwrite(buffer, sizeof(uint32_t), 512, stdout);
        fflush(stdout);
    }
    
    return 0;
}
